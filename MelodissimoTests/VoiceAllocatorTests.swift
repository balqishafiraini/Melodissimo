import XCTest
@testable import Melodissimo

final class VoiceAllocatorTests: XCTestCase {

    func testPicksFreeVoicesInTurn() {
        var allocator = VoiceAllocator(count: 3)
        XCTAssertEqual(allocator.start(note: "a").voice, 0)
        XCTAssertEqual(allocator.start(note: "b").voice, 1)
        XCTAssertEqual(allocator.start(note: "c").voice, 2)
    }

    func testStealsTheOldestWhenEveryVoiceIsBusy() {
        var allocator = VoiceAllocator(count: 2)
        _ = allocator.start(note: "a")
        _ = allocator.start(note: "b")
        let stolen = allocator.start(note: "c")
        XCTAssertEqual(stolen.voice, 0, "a was started first")
        XCTAssertNil(allocator.voice(for: "a"))
        XCTAssertEqual(allocator.voice(for: "c"), 0)
        XCTAssertEqual(allocator.start(note: "d").voice, 1, "now b is the oldest")
    }

    func testRetriggeringANoteReusesItsVoiceAndBumpsTheGeneration() {
        var allocator = VoiceAllocator(count: 4)
        let first = allocator.start(note: "a")
        _ = allocator.start(note: "b")
        let second = allocator.start(note: "a")
        XCTAssertEqual(second.voice, first.voice)
        XCTAssertEqual(second.generation, first.generation + 1)
        XCTAssertEqual(allocator.voices.filter { $0.note == "a" }.count, 1)
    }

    func testAFreedVoiceIsPreferredOverStealing() {
        var allocator = VoiceAllocator(count: 2)
        _ = allocator.start(note: "a")
        _ = allocator.start(note: "b")
        let release = allocator.release(note: "b")!
        XCTAssertTrue(allocator.finishRelease(release))
        XCTAssertEqual(allocator.start(note: "c").voice, release.voice, "b's voice is free, a is still sounding")
        XCTAssertEqual(allocator.voice(for: "a"), 0)
    }

    func testAStopThatArrivesAfterARetriggerIsIgnored() {
        var allocator = VoiceAllocator(count: 2)
        _ = allocator.start(note: "a")
        let fade = allocator.release(note: "a")!          // key lifted: a fade-out begins
        let again = allocator.start(note: "a")            // pressed again before the fade ends
        XCTAssertFalse(allocator.isCurrent(voice: fade.voice, generation: fade.generation))
        XCTAssertFalse(allocator.finishRelease(fade), "the late stop must not cut the new sound")
        XCTAssertEqual(allocator.voice(for: "a"), again.voice)
    }

    func testAStopThatArrivesAfterTheVoiceWasStolenIsIgnored() {
        var allocator = VoiceAllocator(count: 1)
        _ = allocator.start(note: "a")
        let fade = allocator.release(note: "a")!
        _ = allocator.start(note: "b")                    // steals the only voice
        XCTAssertFalse(allocator.finishRelease(fade))
        XCTAssertEqual(allocator.voice(for: "b"), 0)
    }

    func testReleasingANoteWithoutAVoiceDoesNothing() {
        let allocator = VoiceAllocator(count: 2)
        XCTAssertNil(allocator.release(note: "x"))
    }

    func testStopAllFreesEverythingAndStalesPendingFades() {
        var allocator = VoiceAllocator(count: 3)
        _ = allocator.start(note: "a")
        _ = allocator.start(note: "b")
        let fade = allocator.release(note: "a")!
        XCTAssertEqual(Set(allocator.stopAll()), [0, 1])
        XCTAssertTrue(allocator.stopAll().isEmpty, "idempotent")
        XCTAssertFalse(allocator.finishRelease(fade))
        XCTAssertNil(allocator.voice(for: "a"))
        XCTAssertNil(allocator.voice(for: "b"))
    }
}
