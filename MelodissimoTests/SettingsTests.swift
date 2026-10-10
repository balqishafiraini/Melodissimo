import XCTest
@testable import Melodissimo

final class AudioCalibrationTests: XCTestCase {

    func testABeatRunHasEightBeatsSpacedByTheInterval() {
        let beats = AudioCalibration.beatTimes(start: 100)
        XCTAssertEqual(beats.count, 8)
        XCTAssertEqual(beats[0], 100 + AudioCalibration.leadIn, accuracy: 1e-9)
        for index in 1..<beats.count {
            XCTAssertEqual(beats[index] - beats[index - 1], AudioCalibration.beatInterval, accuracy: 1e-9)
        }
    }

    func testTapsAreMeasuredAgainstTheNearestBeat() {
        let beats = [10.0, 10.75, 11.5]
        let offsets = AudioCalibration.tapOffsets(beats: beats, taps: [10.08, 10.70, 11.59])
        XCTAssertEqual(offsets.count, 3)
        XCTAssertEqual(offsets[0], 0.08, accuracy: 1e-9)
        XCTAssertEqual(offsets[1], -0.05, accuracy: 1e-9)
        XCTAssertEqual(offsets[2], 0.09, accuracy: 1e-9)
    }

    func testAStrayTapFarFromEveryBeatIsIgnored() {
        let beats = [10.0, 10.75]
        // 0.37 s after the first beat and 0.38 s before the second: neither is within the tolerance.
        XCTAssertTrue(AudioCalibration.tapOffsets(beats: beats, taps: [10.37]).isEmpty)
        XCTAssertTrue(AudioCalibration.tapOffsets(beats: [], taps: [10]).isEmpty)
    }

    func testLateTapsSuggestAPositiveOffset() {
        let beats = AudioCalibration.beatTimes(start: 0)
        let taps = beats.map { $0 + 0.080 }
        XCTAssertEqual(AudioCalibration.suggestedOffsetMs(beats: beats, taps: taps), 80)
    }

    func testEarlyTapsSuggestANegativeOffset() {
        let beats = AudioCalibration.beatTimes(start: 0)
        let taps = beats.map { $0 - 0.045 }
        XCTAssertEqual(AudioCalibration.suggestedOffsetMs(beats: beats, taps: taps), -45)
    }

    func testTheSuggestionIsTheAverageOfTheTaps() {
        let beats = AudioCalibration.beatTimes(start: 0)
        let lateBy = [0.02, 0.06, 0.10, 0.04, 0.08, 0.06, 0.06, 0.06]   // mean 60 ms
        let taps = zip(beats, lateBy).map { $0 + $1 }
        XCTAssertEqual(AudioCalibration.suggestedOffsetMs(beats: beats, taps: taps), 60)
    }

    func testTheSuggestionIsClampedToTheSettingsRange() {
        let beats = AudioCalibration.beatTimes(start: 0)
        // Always 0.25 s late: inside the tolerance, outside the +150 ms range.
        XCTAssertEqual(AudioCalibration.suggestedOffsetMs(beats: beats, taps: beats.map { $0 + 0.25 }), 150)
        XCTAssertEqual(AudioCalibration.suggestedOffsetMs(beats: beats, taps: beats.map { $0 - 0.25 }), -150)
    }

    func testTooFewTapsGiveNoSuggestion() {
        let beats = AudioCalibration.beatTimes(start: 0)
        XCTAssertNil(AudioCalibration.suggestedOffsetMs(beats: beats, taps: Array(beats.prefix(3))))
        XCTAssertNil(AudioCalibration.suggestedOffsetMs(beats: beats, taps: []))
    }
}

final class CalibrationViewModelTests: XCTestCase {

    func testItStartsIdleAndIgnoresTapsAndSteps() {
        let model = CalibrationViewModel()
        XCTAssertEqual(model.phase, .idle)
        model.tap(now: 1)
        model.step(now: 100)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertTrue(model.taps.isEmpty)
    }

    func testBeatsFireInOrderAsTimePasses() {
        let model = CalibrationViewModel()
        var fired: [Int] = []
        model.onBeat = { fired.append($0) }
        model.start(now: 0)

        model.step(now: AudioCalibration.leadIn - 0.01)
        XCTAssertEqual(fired, [])
        model.step(now: AudioCalibration.leadIn)
        XCTAssertEqual(fired, [0])
        XCTAssertEqual(model.beatsPlayed, 1)

        // A long gap (a dropped frame) still fires every beat that is due, once.
        model.step(now: AudioCalibration.leadIn + 3 * AudioCalibration.beatInterval + 0.01)
        XCTAssertEqual(fired, [0, 1, 2, 3])
        model.step(now: AudioCalibration.leadIn + 3 * AudioCalibration.beatInterval + 0.02)
        XCTAssertEqual(fired, [0, 1, 2, 3])
    }

    func testTheRunEndsAfterTheLastBeatPlusTheTail() {
        let model = CalibrationViewModel()
        model.start(now: 0)
        let lastBeat = model.beats.last!
        model.step(now: lastBeat + CalibrationViewModel.tail - 0.01)
        XCTAssertEqual(model.phase, .running)
        model.step(now: lastBeat + CalibrationViewModel.tail)
        XCTAssertEqual(model.phase, .finished)
        XCTAssertEqual(model.beatsPlayed, AudioCalibration.beatCount)
    }

    func testLateTapsGiveAPositiveSuggestion() {
        let model = CalibrationViewModel()
        model.start(now: 0)
        for beat in model.beats { model.tap(now: beat + 0.05) }
        model.step(now: model.beats.last! + CalibrationViewModel.tail)
        XCTAssertEqual(model.suggestion, 50)
    }

    func testTooFewTapsLeaveNoSuggestion() {
        let model = CalibrationViewModel()
        model.start(now: 0)
        model.tap(now: model.beats[0])
        model.step(now: model.beats.last! + CalibrationViewModel.tail)
        XCTAssertEqual(model.phase, .finished)
        XCTAssertNil(model.suggestion)
    }

    func testTapsAfterTheRunAreIgnoredAndResetStartsOver() {
        let model = CalibrationViewModel()
        model.start(now: 0)
        model.step(now: model.beats.last! + CalibrationViewModel.tail)
        model.tap(now: 50)
        XCTAssertTrue(model.taps.isEmpty)

        model.reset()
        XCTAssertEqual(model.phase, .idle)
        XCTAssertEqual(model.beatsPlayed, 0)
        XCTAssertNil(model.suggestion)
    }
}

final class SettingsStoreTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaults() {
        XCTAssertEqual(progress.approachTime, 2.0)
        XCTAssertEqual(progress.audioOffsetMs, 0)
        XCTAssertFalse(progress.labelsInPerform)
    }

    func testTheNoteSpeedChoicesAreTheFourFromThePlan() {
        XCTAssertEqual(ProgressStore.approachTimeChoices, [1.5, 2.0, 2.5, 3.0])
    }

    func testApproachTimeIsStoredAndAnUnknownValueFallsBack() {
        progress.approachTime = 2.5
        XCTAssertEqual(progress.approachTime, 2.5)
        defaults.set(0.2, forKey: "settings_approachTime")
        XCTAssertEqual(progress.approachTime, 2.0)
    }

    func testAudioOffsetIsClampedBothWays() {
        progress.audioOffsetMs = 40
        XCTAssertEqual(progress.audioOffsetMs, 40)
        progress.audioOffsetMs = 900
        XCTAssertEqual(progress.audioOffsetMs, 150)
        progress.audioOffsetMs = -900
        XCTAssertEqual(progress.audioOffsetMs, -150)
        defaults.set(5000, forKey: "settings_audioOffsetMs")
        XCTAssertEqual(progress.audioOffsetMs, 150)
    }

    func testOffsetTextUsesASignAndMilliseconds() {
        XCTAssertEqual(SettingsView.offsetText(0), "0 ms")
        XCTAssertEqual(SettingsView.offsetText(35), "+35 ms")
        XCTAssertEqual(SettingsView.offsetText(-120), "−120 ms")
    }

    // MARK: Reset

    func testTheResetRemovesProgressKeysAndKeepsQuestionSetsThePreplayFlagAndSettings() {
        let progressKeys = [
            "currentLevel", "bestScore_notation_7", "bestCombo", "currentStreak", "longestStreak", "lastPlayedDate",
            "achievement_first_star", "Halo Halo Bandung", "preplayScore", "postplayScore",
            "song_stars_halo-halo-bandung", "song_practiced_halo-halo-bandung", "stage_stars_c1-01",
            "campaign_grantedChapter", "coins_earnedTotal", "coins_spentTotal", "shop_owned", "equip_keyboard",
            "equip_notes", "equip_outfit", "daily_done_20261010", "rush_highScore", "echo_highScore",
            "stat_bossesDefeated", "stat_tourCompletedAt", "story_seen_certificate",
        ]
        let keptKeys = ["Level1", "Level100", "isPreplayDone", "settings_approachTime", "settings_audioOffsetMs",
                        "settings_labelsInPerform", "settings_sfxEnabled"]
        for key in progressKeys + keptKeys { defaults.set(1, forKey: key) }

        progress.resetProgress()

        for key in progressKeys {
            // The migration that follows a reset writes the chapter back, which is intended.
            if key == "campaign_grantedChapter" { continue }
            XCTAssertNil(defaults.object(forKey: key), "\(key) should be gone")
        }
        for key in keptKeys {
            XCTAssertNotNil(defaults.object(forKey: key), "\(key) should stay")
        }
    }

    func testAfterAResetTheTourStartsAtChapterOneWithNothingOwned() {
        progress.earn(500)
        progress.recordStageStars("c1-01", stars: 3)
        defaults.set(95, forKey: "currentLevel")
        progress.runMigrationIfNeeded()
        XCTAssertEqual(progress.grantedChapter, 6)

        progress.resetProgress()

        XCTAssertEqual(progress.coinBalance, 0)
        XCTAssertEqual(progress.stageStars("c1-01"), 0)
        XCTAssertEqual(progress.highestUnlockedLevel, 0)
        XCTAssertEqual(progress.grantedChapter, 1)
        XCTAssertEqual(progress.currentStage.id, "c1-01")
        XCTAssertEqual(progress.purchasedShopItemCount, 0)
    }

    func testOnlyProgressKeysAreResettable() {
        XCTAssertTrue(ProgressStore.isResettableKey("bestScore_notation_3"))
        XCTAssertTrue(ProgressStore.isResettableKey("Berkibarlah Benderaku"))
        XCTAssertFalse(ProgressStore.isResettableKey("Level42"))
        XCTAssertFalse(ProgressStore.isResettableKey("isPreplayDone"))
        XCTAssertFalse(ProgressStore.isResettableKey("settings_audioOffsetMs"))
        XCTAssertFalse(ProgressStore.isResettableKey("AppleLanguages"))
    }
}
