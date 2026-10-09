import XCTest
@testable import Melodissimo

final class CoinRewardsTests: XCTestCase {

    func testEachNewStarPaysTen() {
        XCTAssertEqual(CoinRewards.clear(newStars: 1, isFirstStageClear: false, isFirstBossClear: false), 10)
        XCTAssertEqual(CoinRewards.clear(newStars: 3, isFirstStageClear: false, isFirstBossClear: false), 30)
    }

    func testTheFirstClearAddsTwenty() {
        XCTAssertEqual(CoinRewards.clear(newStars: 2, isFirstStageClear: true, isFirstBossClear: false), 40)
    }

    func testTheFirstBossClearAddsAHundredOnTopOfTheFirstClear() {
        XCTAssertEqual(CoinRewards.clear(newStars: 1, isFirstStageClear: true, isFirstBossClear: true), 10 + 20 + 100)
    }

    func testAReplayWithoutNewStarsPaysFive() {
        XCTAssertEqual(CoinRewards.clear(newStars: 0, isFirstStageClear: false, isFirstBossClear: false), 5)
    }

    func testAReplayThatAddsStarsDoesNotGetTheConsolationToo() {
        XCTAssertEqual(CoinRewards.clear(newStars: 1, isFirstStageClear: false, isFirstBossClear: false), 10)
    }

    func testRushPaysOneCoinPerFiveRightAnswers() {
        XCTAssertEqual(CoinRewards.rush(correctAnswers: 0), 0)
        XCTAssertEqual(CoinRewards.rush(correctAnswers: 4), 0)
        XCTAssertEqual(CoinRewards.rush(correctAnswers: 5), 1)
        XCTAssertEqual(CoinRewards.rush(correctAnswers: 23), 4)
    }

    func testEndlessEchoPaysTwoPerRound() {
        XCTAssertEqual(CoinRewards.echoEndless(rounds: 0), 0)
        XCTAssertEqual(CoinRewards.echoEndless(rounds: 7), 14)
    }

    func testTheDailyRewardGrowsWithTheStreakUpToFiveDays() {
        XCTAssertEqual(CoinRewards.daily(streak: 0), 50)
        XCTAssertEqual(CoinRewards.daily(streak: 1), 60)
        XCTAssertEqual(CoinRewards.daily(streak: 5), 100)
        XCTAssertEqual(CoinRewards.daily(streak: 40), 100)
    }

    func testNegativeInputsNeverPayOrCost() {
        XCTAssertEqual(CoinRewards.clear(newStars: -2, isFirstStageClear: false, isFirstBossClear: false), 5)
        XCTAssertEqual(CoinRewards.rush(correctAnswers: -9), 0)
        XCTAssertEqual(CoinRewards.echoEndless(rounds: -3), 0)
        XCTAssertEqual(CoinRewards.daily(streak: -1), 50)
    }
}

final class CoinWalletTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "CoinWalletTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testANewWalletIsEmpty() {
        XCTAssertEqual(progress.coinBalance, 0)
        XCTAssertEqual(progress.coinsEarnedTotal, 0)
        XCTAssertEqual(progress.coinsSpentTotal, 0)
    }

    func testBalanceIsEarnedMinusSpent() {
        progress.earn(120)
        XCTAssertTrue(progress.spend(50))
        XCTAssertEqual(progress.coinsEarnedTotal, 120)
        XCTAssertEqual(progress.coinsSpentTotal, 50)
        XCTAssertEqual(progress.coinBalance, 70)
    }

    func testSpendingMoreThanTheBalanceChangesNothing() {
        progress.earn(30)
        XCTAssertFalse(progress.spend(31))
        XCTAssertEqual(progress.coinBalance, 30)
        XCTAssertEqual(progress.coinsSpentTotal, 0)
    }

    func testSpendingTheWholeBalanceWorks() {
        progress.earn(30)
        XCTAssertTrue(progress.spend(30))
        XCTAssertEqual(progress.coinBalance, 0)
    }

    func testZeroAndNegativeAmountsAreIgnored() {
        progress.earn(0)
        progress.earn(-10)
        XCTAssertEqual(progress.coinsEarnedTotal, 0)
        progress.earn(10)
        XCTAssertFalse(progress.spend(0))
        XCTAssertFalse(progress.spend(-5))
        XCTAssertEqual(progress.coinBalance, 10)
    }

    func testTotalsOnlyEverIncreaseAndAreStoredUnderTheDocumentedKeys() {
        progress.earn(10)
        progress.earn(15)
        progress.spend(5)
        XCTAssertEqual(defaults.integer(forKey: "coins_earnedTotal"), 25)
        XCTAssertEqual(defaults.integer(forKey: "coins_spentTotal"), 5)
    }

    func testTheBalanceSurvivesANewStoreOnTheSameDefaults() {
        progress.earn(80)
        progress.spend(30)
        XCTAssertEqual(ProgressStore(defaults: defaults).coinBalance, 50)
    }
}

final class CoinRecordingTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var recorder: ResultRecorder!

    override func setUp() {
        super.setUp()
        suiteName = "CoinRecordingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let songId = SongLibrary.slug(for: "Terima Kasih Guru")

    private func battle(stage: String?, won: Bool = true, hearts: Int = 3) -> PlayResult {
        let config = BattleConfig(newPool: [5, 6, 7], questionCount: 6, timePerNote: nil, seed: 1)
        return PlayResult(request: PlayRequest(kind: .battle(config), campaignStageId: stage), didWin: won,
                          stars: won ? hearts : 0, score: 60, accuracy: 100, maxCombo: 6,
                          perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
    }

    private func song(mode: StageMode, stars: Int, stage: String? = nil, boss: Bool = false) -> PlayResult {
        let kind = PlayRequest.Kind.song(songId: songId, mode: mode, speed: 1, isBoss: boss, isSolemn: false, noteLimit: nil)
        return PlayResult(request: PlayRequest(kind: kind, campaignStageId: stage), didWin: stars > 0 || mode == .practice,
                          stars: stars, score: 900, accuracy: 80, maxCombo: 8,
                          perfect: 5, great: 3, good: 2, miss: 1, wrong: 0)
    }

    // MARK: Stages

    func testFirstClearOfAStageWithThreeStarsPaysFifty() {
        let rewards = recorder.record(battle(stage: "c1-01", hearts: 3))
        XCTAssertEqual(rewards.coins, 3 * 10 + 20)
        XCTAssertEqual(progress.coinBalance, 50)
    }

    func testReplayingWithNoNewStarsPaysFive() {
        recorder.record(battle(stage: "c1-01", hearts: 3))
        let rewards = recorder.record(battle(stage: "c1-01", hearts: 3))
        XCTAssertEqual(rewards.coins, 5)
        XCTAssertEqual(progress.coinBalance, 55)
    }

    func testImprovingAStageOnlyPaysForTheExtraStars() {
        recorder.record(battle(stage: "c1-01", hearts: 1))
        let rewards = recorder.record(battle(stage: "c1-01", hearts: 3))
        XCTAssertEqual(rewards.coins, 2 * 10)
    }

    func testALostStagePaysNothing() {
        let rewards = recorder.record(battle(stage: "c1-01", won: false))
        XCTAssertEqual(rewards.coins, 0)
        XCTAssertEqual(progress.coinBalance, 0)
    }

    func testTheClassicLevelsPayNothing() {
        let result = PlayResult(request: PlayRequest(kind: .classic(levelNo: 3)), didWin: true, stars: 3, score: 100,
                                accuracy: 100, maxCombo: 10, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        XCTAssertEqual(recorder.record(result).coins, 0)
        XCTAssertEqual(progress.coinBalance, 0)
    }

    // MARK: Songs and bosses

    func testAFreeSongPaysByNewStarsThenTheConsolation() {
        XCTAssertEqual(recorder.record(song(mode: .perform, stars: 2)).coins, 20)
        XCTAssertEqual(recorder.record(song(mode: .perform, stars: 2)).coins, 5)
        XCTAssertEqual(recorder.record(song(mode: .perform, stars: 3)).coins, 10)
    }

    func testACampaignSongPaysTheStarsOnceNotTwice() {
        // The song's own best and the stage's best both go up, but the stars are paid once, plus the first clear.
        let rewards = recorder.record(song(mode: .perform, stars: 2, stage: "c1-04"))
        XCTAssertEqual(rewards.coins, 2 * 10 + 20)
    }

    func testAFailedPerformPaysNothing() {
        XCTAssertEqual(recorder.record(song(mode: .perform, stars: 0)).coins, 0)
    }

    func testTheFirstBossClearPaysAHundredMore() {
        let rewards = recorder.record(song(mode: .perform, stars: 1, stage: "c1-07", boss: true))
        XCTAssertEqual(rewards.coins, 10 + 20 + 100)
        XCTAssertEqual(recorder.record(song(mode: .perform, stars: 1, stage: "c1-07", boss: true)).coins, 5)
    }

    func testPracticePaysFifteenOnlyTheFirstTime() {
        XCTAssertEqual(recorder.record(song(mode: .practice, stars: 0)).coins, 15)
        XCTAssertEqual(recorder.record(song(mode: .practice, stars: 0)).coins, 0)
    }

    func testPracticingACampaignSongStageDoesNotCountAsClearingIt() {
        let rewards = recorder.record(song(mode: .practice, stars: 0, stage: "c1-04"))
        XCTAssertEqual(rewards.coins, 15)
        XCTAssertEqual(progress.stageStars("c1-04"), 0)
    }

    func testListeningPaysNothing() {
        XCTAssertEqual(recorder.record(song(mode: .listen, stars: 0)).coins, 0)
        XCTAssertEqual(progress.coinBalance, 0)
    }

    // MARK: Endless modes

    func testRushPaysOneCoinPerFiveRightAnswers() {
        let result = PlayResult(request: PlayRequest(kind: .rush), didWin: false, stars: 0, score: 640, accuracy: nil,
                                maxCombo: 12, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0, correctCount: 23)
        XCTAssertEqual(recorder.record(result).coins, 4)
        XCTAssertEqual(progress.coinBalance, 4)
    }

    func testEndlessEchoPaysTwoPerRound() {
        let config = EchoConfig(pool: Array(5...12), roundsToClear: nil, startLength: 2, maxLength: 8,
                                glowDuringPlayback: true, useSongSnippets: false, seed: 1)
        let result = PlayResult(request: PlayRequest(kind: .echo(config)), didWin: false, stars: 0, score: 6, accuracy: nil,
                                maxCombo: 0, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        XCTAssertEqual(recorder.record(result).coins, 12)
    }

    func testACampaignEchoPaysLikeAStage() {
        let config = EchoConfig(pool: Array(5...12), roundsToClear: 3, startLength: 2, glowDuringPlayback: true, seed: 1)
        let result = PlayResult(request: PlayRequest(kind: .echo(config), campaignStageId: "c1-03"), didWin: true, stars: 2,
                                score: 3, accuracy: nil, maxCombo: 0, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        XCTAssertEqual(recorder.record(result).coins, 2 * 10 + 20)
    }

    // MARK: Totals

    func testCoinsAccumulateAcrossPlays() {
        recorder.record(battle(stage: "c1-01", hearts: 3))                       // 50
        recorder.record(song(mode: .practice, stars: 0))                         // 15
        recorder.record(song(mode: .perform, stars: 1, stage: "c1-07", boss: true)) // 130
        XCTAssertEqual(progress.coinBalance, 195)
        XCTAssertEqual(progress.coinsEarnedTotal, 195)
    }
}
