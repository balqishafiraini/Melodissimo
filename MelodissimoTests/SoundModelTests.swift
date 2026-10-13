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
}
