import XCTest
@testable import Melodissimo

final class BackingScheduleTests: XCTestCase {

    func testLeadInIsTheCountInForAShortIntro() {
        XCTAssertEqual(BackingSchedule.leadIn(offset: 1, speed: 1, countIn: 2), 2, accuracy: 1e-9)
        XCTAssertEqual(BackingSchedule.leadIn(offset: 0, speed: 1, countIn: 2), 2, accuracy: 1e-9)
    }

    func testLeadInFollowsALongIntroUpToTheCap() {
        XCTAssertEqual(BackingSchedule.leadIn(offset: 4, speed: 1, countIn: 2), 4, accuracy: 1e-9)
        // 20 s intro: count-in + 4
        XCTAssertEqual(BackingSchedule.leadIn(offset: 20, speed: 1, countIn: 2), 6, accuracy: 1e-9)
        // Slower playback stretches the intro: 6 s at 0.5× is 12 s of wall time, capped at 2 + 4.
        XCTAssertEqual(BackingSchedule.leadIn(offset: 6, speed: 0.5, countIn: 2), 6, accuracy: 1e-9)
        XCTAssertEqual(BackingSchedule.leadIn(offset: 2.5, speed: 0.5, countIn: 2), 5, accuracy: 1e-9)
    }

    func testStartWithAPositivePosition() {
        let s = BackingSchedule.start(songTime: -3, speed: 1, offset: 5, outputLatency: 0)
        XCTAssertEqual(s.position, 2, accuracy: 1e-9)
        XCTAssertEqual(s.delay, 0, accuracy: 1e-9)
    }

    func testStartWithANegativePositionWaitsInsteadOfSeeking() {
        // The clock is 6 s before beat 0 but the track only has 2 s of intro: wait 4 s.
        let s = BackingSchedule.start(songTime: -6, speed: 1, offset: 2, outputLatency: 0)
        XCTAssertEqual(s.position, 0, accuracy: 1e-9)
        XCTAssertEqual(s.delay, 4, accuracy: 1e-9)
        // At 0.5× the same 4 track-seconds take 8 wall seconds.
        let slow = BackingSchedule.start(songTime: -6, speed: 0.5, offset: 2, outputLatency: 0)
        XCTAssertEqual(slow.delay, 2, accuracy: 1e-9)   // position = 2 - 3 = -1 → wait 1 / 0.5
    }

    func testOutputLatencyIsSentAhead() {
        let s = BackingSchedule.start(songTime: 0, speed: 0.5, offset: 10, outputLatency: 0.04)
        XCTAssertEqual(s.position, 10.02, accuracy: 1e-9)
    }

    func testNeedsResync() {
        XCTAssertFalse(BackingSchedule.needsResync(expected: 10, actual: 10.04))
        XCTAssertTrue(BackingSchedule.needsResync(expected: 10, actual: 10.06))
        XCTAssertTrue(BackingSchedule.needsResync(expected: 10, actual: 9.9))
    }
}
