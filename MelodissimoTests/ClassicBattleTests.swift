import XCTest
@testable import Melodissimo

final class ClassicBattleConfigTests: XCTestCase {

    func testQuestionsAreTheLevelsExactSequence() {
        let config = BattleConfig.classic(levelNo: 3, answers: [5, 9, 5, 12])
        XCTAssertEqual(config.fixedQuestions, [5, 9, 5, 12])
        XCTAssertEqual(config.totalQuestions, 4)
        XCTAssertFalse(config.isEndless)
        XCTAssertEqual(config.newPool, [5, 9, 12])
        XCTAssertEqual(config.hearts, 3)
        XCTAssertEqual(config.seed, 3)
    }

    func testNoTimerOnTheFirstTenLevels() {
        for level in 1...10 {
            XCTAssertNil(BattleConfig.classic(levelNo: level, answers: [5]).timePerNote, "level \(level)")
        }
    }

    func testTimerShrinksFromSixSecondsDownToThree() {
        func timer(_ level: Int) -> Double? { BattleConfig.classic(levelNo: level, answers: [5]).timePerNote }
        XCTAssertEqual(timer(11) ?? 0, 6 - 0.33, accuracy: 1e-9)
        XCTAssertEqual(timer(50) ?? 0, 4.5, accuracy: 1e-9)
        XCTAssertEqual(timer(100) ?? 0, 3, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(timer(100) ?? 0, 3, "never below 3 s")
    }

    func testEveryFifthLevelIsABoss() {
        for level in 1...100 {
            XCTAssertEqual(BattleConfig.classic(levelNo: level, answers: [5]).isBoss, level % 5 == 0, "level \(level)")
        }
    }

    func testRealLevelsPlayThroughTheBattleLogic() {
        let level = LevelFeederModel.shared.notationQuizLevels[11]
        let vm = BattleViewModel(config: .classic(levelNo: level.levelNo, answers: level.answer))
        XCTAssertEqual(vm.monsterHP, level.answer.count)
        var asked: [Int] = []
        while vm.phase == .playing {
            asked.append(vm.currentQuestion)
            vm.answer(keyId: vm.currentQuestion, now: 0)
        }
        XCTAssertEqual(asked, level.answer)
        XCTAssertEqual(vm.phase, .won)
        XCTAssertEqual(vm.stars, 3)
        XCTAssertEqual(vm.firstTryPercent, 100)
    }
}

final class ClassicResultRecordingTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var recorder: ResultRecorder!

    override func setUp() {
        super.setUp()
        suiteName = "ClassicResultRecordingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func result(level: Int, won: Bool, firstTryPercent: Double, hearts: Int = 3, score: Int = 100) -> PlayResult {
        PlayResult(request: PlayRequest(kind: .classic(levelNo: level)), didWin: won, stars: won ? hearts : 0,
                   score: score, accuracy: firstTryPercent, maxCombo: 5,
                   perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
    }

    func testFirstTryPercentBecomesTheLevelScoreAndStars() {
        recorder.record(result(level: 4, won: true, firstTryPercent: 83))
        XCTAssertEqual(progress.bestScore(category: "notation", level: 4), 83)
        XCTAssertEqual(progress.stars(category: "notation", level: 4), 2, "80 % and up is two stars")
    }

    func testStarThresholdsStayAtSixtyEightyAndAHundred() {
        // One level per percentage so each run starts from nothing.
        for (offset, (percent, stars)) in [(59, 0), (60, 1), (79, 1), (80, 2), (99, 2), (100, 3)].enumerated() {
            let level = 20 + offset
            recorder.record(result(level: level, won: true, firstTryPercent: Double(percent)))
            XCTAssertEqual(progress.stars(category: "notation", level: level), stars, "\(percent) %")
        }
    }

    func testOnlyTheBestScoreIsKept() {
        recorder.record(result(level: 2, won: true, firstTryPercent: 90))
        recorder.record(result(level: 2, won: true, firstTryPercent: 60))
        XCTAssertEqual(progress.bestScore(category: "notation", level: 2), 90)
    }

    func testWinningUnlocksTheLevelAndALossDoesNot() {
        XCTAssertEqual(progress.highestUnlockedLevel, 0)
        recorder.record(result(level: 1, won: false, firstTryPercent: 40))
        XCTAssertEqual(progress.highestUnlockedLevel, 0)
        recorder.record(result(level: 1, won: true, firstTryPercent: 70))
        XCTAssertEqual(progress.highestUnlockedLevel, 1, "the grid then opens level 2")
        recorder.record(result(level: 3, won: true, firstTryPercent: 100))
        XCTAssertEqual(progress.highestUnlockedLevel, 3)
        recorder.record(result(level: 2, won: true, firstTryPercent: 100))
        XCTAssertEqual(progress.highestUnlockedLevel, 3, "replaying an earlier level never lowers it")
    }

    func testClassicPlaysStillCountForStreakAndCombo() {
        recorder.record(result(level: 1, won: true, firstTryPercent: 100))
        XCTAssertEqual(progress.currentStreak, 1)
        XCTAssertEqual(progress.bestCombo, 5)
    }

    func testClassicPlaysDoNotTouchSongProgress() {
        recorder.record(result(level: 1, won: true, firstTryPercent: 100))
        XCTAssertEqual(progress.statSongsPerformed, 0)
    }

    func testLegacyKeysAreUntouched() {
        recorder.record(result(level: 12, won: true, firstTryPercent: 100))
        XCTAssertEqual(defaults.integer(forKey: "bestScore_notation_12"), 100)
        XCTAssertEqual(defaults.integer(forKey: "currentLevel"), 12)
    }
}
