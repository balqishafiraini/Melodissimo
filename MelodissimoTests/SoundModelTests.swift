import XCTest
@testable import Melodissimo

final class SoundModelTests: XCTestCase {

    func testPreloadWarmsAllThirtyTwoSamples() {
        let warm = expectation(description: "samples preloaded")
        preloadAllSounds { warm.fulfill() }
        wait(for: [warm], timeout: 10)
        XCTAssertEqual(preloadedSoundCount, 32)
    }

    func testStopAllSoundsSilencesEveryNote() {
        let warm = expectation(description: "samples preloaded")
        preloadAllSounds { warm.fulfill() }
        wait(for: [warm], timeout: 10)
        playSound(key: "c2")
        playSound(key: NoteCatalog.note(6).sound)
        stopAllSounds()
        stopAllSounds()   // idempotent
    }

    func testStopSoundForOneKeyDoesNotAffectOthersOrCrash() {
        // Unknown keys and keys that never played are no-ops.
        stopSound(key: "does-not-exist")
        stopSound(key: "c2")
        stopSound()
    }

    func testLongNotesAreTrimmedToThreeSecondsInTheSharedMonoFormat() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "c2", withExtension: "m4a"))   // ~5.7 s on disk
        let buffer = try XCTUnwrap(NoteAudioEngine.makeBuffer(url: url, maxSeconds: NoteAudioEngine.maxNoteSeconds))
        XCTAssertEqual(buffer.format.channelCount, 1)
        XCTAssertEqual(buffer.format.sampleRate, 48_000)
        XCTAssertEqual(Double(buffer.frameLength) / 48_000, 3.0, accuracy: 0.05)
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        XCTAssertEqual(samples[Int(buffer.frameLength) - 1], 0, accuracy: 0.01, "the cut ends in silence, not a click")
    }

    func testStereoEffectsAreMixedDownAndResampled() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "sfx_miss", withExtension: "caf"))   // stereo, 44.1 kHz
        let buffer = try XCTUnwrap(NoteAudioEngine.makeBuffer(url: url))
        XCTAssertEqual(buffer.format.channelCount, 1)
        XCTAssertEqual(buffer.format.sampleRate, 48_000)
        XCTAssertEqual(Double(buffer.frameLength) / 48_000, 0.191, accuracy: 0.01)
    }

    func testAMissingFileGivesNoBuffer() {
        XCTAssertNil(NoteAudioEngine.makeBuffer(url: URL(fileURLWithPath: "/nonexistent.m4a")))
    }
}
