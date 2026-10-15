import XCTest
@testable import Melodissimo

final class SFXTests: XCTestCase {

    func testTheEffectsAreTheTenNamesFromThePlan() {
        let names = SFX.Effect.allCases.map(\.rawValue)
        XCTAssertEqual(Set(names), ["sfx_perfect", "sfx_miss", "sfx_wrong", "sfx_coin", "sfx_star",
                                    "sfx_unlock", "sfx_monster_hit", "sfx_player_hurt", "sfx_tick", "sfx_button"])
        XCTAssertEqual(names.count, 10)
    }

    func testEveryEffectIsBundledAsAPlayableFile() {
        // A plain AVAudioPlayer can't read the Kenney .ogg originals, so the converted .caf must be in the app.
        let sfx = SFX(bundle: .main, isEnabled: { true })
        for effect in SFX.Effect.allCases {
            XCTAssertNotNil(Bundle.main.url(forResource: effect.rawValue, withExtension: SFX.fileExtension), effect.rawValue)
            XCTAssertTrue(sfx.canPlay(effect.rawValue), "\(effect.rawValue) should decode")
        }
    }

    func testPreloadDecodesOffTheMainThreadAndHandsTheEffectsOverOnMain() {
        let sfx = SFX(bundle: .main, isEnabled: { true })
        let done = expectation(description: "preload finished")
        sfx.preload {
            XCTAssertTrue(Thread.isMainThread, "the pools are only touched on the main thread")
            done.fulfill()
        }
        // Launch isn't held up: `preload` returns before the decoding is done, and an effect is playable at once.
        XCTAssertTrue(sfx.canPlay(SFX.Effect.button.rawValue))
        wait(for: [done], timeout: 10)
        for effect in SFX.Effect.allCases {
            XCTAssertTrue(sfx.canPlay(effect.rawValue), effect.rawValue)
        }
        XCTAssertTrue(sfx.play(SFX.Effect.button.rawValue))
    }

    func testAMissingFileIsSilentlySkipped() {
        let sfx = SFX(bundle: .main, isEnabled: { true })
        XCTAssertFalse(sfx.canPlay("sfx_does_not_exist"))
        XCTAssertFalse(sfx.play("sfx_does_not_exist"), "no crash, nothing played")
        XCTAssertFalse(sfx.play("sfx_does_not_exist"), "and asking again is fine")
    }

    func testNothingPlaysWhileTheSettingIsOff() {
        var enabled = false
        let sfx = SFX(bundle: .main, isEnabled: { enabled })
        XCTAssertFalse(sfx.play(SFX.Effect.perfect.rawValue))
        enabled = true
        XCTAssertTrue(sfx.canPlay(SFX.Effect.perfect.rawValue))
    }

    func testEffectsPlayBelowTheNoteSamples() {
        XCTAssertEqual(SFX.volume, 0.6, accuracy: 1e-6)
    }

    func testTheSettingDefaultsToOnAndIsStored() {
        let suite = "SFXTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ProgressStore(defaults: defaults)
        XCTAssertTrue(progress.sfxEnabled)
        progress.sfxEnabled = false
        XCTAssertFalse(progress.sfxEnabled)
        progress.sfxEnabled = true
        XCTAssertTrue(progress.sfxEnabled)
    }

    func testResettingProgressKeepsTheSoundSetting() {
        let suite = "SFXTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ProgressStore(defaults: defaults)
        progress.sfxEnabled = false
        progress.resetProgress()
        XCTAssertFalse(progress.sfxEnabled)
    }
}
