import XCTest
@testable import Melodissimo

private final class FakeWallet: ReviveWallet {
    var hearts: Int
    var coins: Int
    var heartsUsed = 0
    var coinsSpent = 0
    init(hearts: Int = 0, coins: Int = 0) { self.hearts = hearts; self.coins = coins }
    var reviveHeartCount: Int { hearts }
    var reviveBalance: Int { coins }
    func useReviveHeart() -> Bool {
        guard hearts > 0 else { return false }
        hearts -= 1; heartsUsed += 1
        return true
    }
    func spendReviveCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount; coinsSpent += amount
        return true
    }
}

final class ReviveRulesTests: XCTestCase {

    private let rules = ReviveRules.defaults

    private func options(used: Int = 0, plusUsed: Int = 0, plus: Bool = false, hearts: Int = 0, balance: Int = 0,
                         daily: Bool = false, rules: ReviveRules = .defaults) -> [ReviveOption] {
        Revive.options(rules: rules, revivesUsed: used, plusFreeUsed: plusUsed, isPlus: plus,
                       heartCount: hearts, balance: balance, isDaily: daily)
    }

    func testTheDefaultsMatchThePlan() {
        XCTAssertEqual(rules, ReviveRules(coinCost: 50, heartsRestored: 1, maxPerRun: 2, starCap: 1,
                                          plusFreeRevivesPerRun: 1, reviveInDaily: false))
    }

    func testCoinsAreAlwaysOfferedAndShowWhetherTheyAreAffordable() {
        XCTAssertEqual(options(balance: 49), [ReviveOption(source: .coins, cost: 50, isAffordable: false)])
        XCTAssertEqual(options(balance: 50), [ReviveOption(source: .coins, cost: 50, isAffordable: true)])
    }

    func testAHeartIsOfferedFirstWhenThePlayerHasOne() {
        XCTAssertEqual(options(hearts: 2, balance: 80).map(\.source), [.heart, .coins])
    }

    func testAPlusMemberGetsTheFreeReviveFirstAndOnly() {
        XCTAssertEqual(options(plus: true, hearts: 3, balance: 500).map(\.source), [.plus])
        XCTAssertEqual(options(used: 1, plusUsed: 1, plus: true, hearts: 3, balance: 500).map(\.source), [.heart, .coins])
    }

    func testNoMoreThanMaxPerRun() {
        XCTAssertTrue(options(used: 2, hearts: 5, balance: 500).isEmpty)
        XCTAssertFalse(options(used: 1, hearts: 5, balance: 500).isEmpty)
    }

    func testNoReviveInTheDailyChallengeUnlessTheFlagIsOn() {
        XCTAssertTrue(options(hearts: 5, balance: 500, daily: true).isEmpty)
        var on = rules
        on.reviveInDaily = true
        XCTAssertFalse(options(hearts: 5, balance: 500, daily: true, rules: on).isEmpty)
    }

    func testTheStarCapOnlyAppliesAfterARevive() {
        XCTAssertEqual(Revive.cappedStars(3, revivesUsed: 0, rules: rules), 3)
        XCTAssertEqual(Revive.cappedStars(3, revivesUsed: 1, rules: rules), 1)
        XCTAssertEqual(Revive.cappedStars(0, revivesUsed: 1, rules: rules), 0)
        XCTAssertTrue(Revive.countsForLeaderboard(revivesUsed: 0))
        XCTAssertFalse(Revive.countsForLeaderboard(revivesUsed: 1))
    }

    // MARK: ReviveRun

    func testAHeartRevivePaysExactlyOneHeart() {
        let wallet = FakeWallet(hearts: 2, coins: 100)
        let run = ReviveRun(isDaily: false, isPlus: false, wallet: wallet)
        XCTAssertTrue(run.perform(.heart))
        XCTAssertEqual(wallet.heartsUsed, 1)
        XCTAssertEqual(wallet.coinsSpent, 0)
        XCTAssertEqual(run.revivesUsed, 1)
    }

    func testACoinRevivePaysTheCostOnce() {
        let wallet = FakeWallet(coins: 120)
        let run = ReviveRun(isDaily: false, isPlus: false, wallet: wallet)
        XCTAssertTrue(run.perform(.coins))
        XCTAssertEqual(wallet.coinsSpent, 50)
        XCTAssertEqual(wallet.heartsUsed, 0)
    }

    func testAnUnaffordableOrUnofferedSourceChangesNothing() {
        let wallet = FakeWallet(hearts: 0, coins: 10)
        let run = ReviveRun(isDaily: false, isPlus: false, wallet: wallet)
        XCTAssertFalse(run.perform(.coins))
        XCTAssertFalse(run.perform(.heart))
        XCTAssertFalse(run.perform(.plus))
        XCTAssertEqual(run.revivesUsed, 0)
        XCTAssertEqual(wallet.coins, 10)
    }

    func testPlusRevivesAreFreeAndLimited() {
        let wallet = FakeWallet(coins: 500)
        let run = ReviveRun(isDaily: false, isPlus: true, wallet: wallet)
        XCTAssertTrue(run.perform(.plus))
        XCTAssertEqual(wallet.coinsSpent, 0)
        XCTAssertFalse(run.perform(.plus), "only one free revive per run")
        XCTAssertTrue(run.perform(.coins))
        XCTAssertFalse(run.perform(.coins), "max two revives per run")
        XCTAssertEqual(run.revivesUsed, 2)
    }

    func testTheRealWalletIsTheProgressStore() {
        let suite = "ReviveWallet-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ProgressStore(defaults: defaults)
        progress.earn(60)
        progress.addToInventory(ReviveRules.heartItemId, count: 1)
        let run = ReviveRun(isDaily: false, isPlus: false, wallet: progress)
        XCTAssertTrue(run.perform(.heart))
        XCTAssertTrue(run.perform(.coins))
        XCTAssertEqual(progress.inventoryCount(ReviveRules.heartItemId), 0)
        XCTAssertEqual(progress.coinBalance, 10)
    }
}

final class ReviveGameTests: XCTestCase {

    private func run(hearts: Int = 0, coins: Int = 100, plus: Bool = false, daily: Bool = false) -> (ReviveRun, FakeWallet) {
        let wallet = FakeWallet(hearts: hearts, coins: coins)
        return (ReviveRun(isDaily: daily, isPlus: plus, wallet: wallet), wallet)
    }

    // MARK: Battle

    private func battle(_ run: ReviveRun?, hearts: Int = 1) -> BattleViewModel {
        let config = BattleConfig(newPool: [5, 6, 7], reviewPool: [], questionCount: 5, timePerNote: nil,
                                  hearts: hearts, isBoss: false, fixedQuestions: nil, seed: 1)
        let vm = BattleViewModel(config: config, reviveRun: run)
        vm.start(now: 0)
        return vm
    }

    private func wrongKey(_ vm: BattleViewModel) -> Int { vm.currentQuestion == 30 ? 31 : 30 }

    func testWithoutARunTheBattleIsLostAtZeroHearts() {
        let vm = battle(nil)
        vm.answer(keyId: wrongKey(vm), now: 1)
        XCTAssertEqual(vm.phase, .lost)
    }

    func testZeroHeartsWaitForTheContinueSheetWhenARevivePaysOff() {
        let (r, _) = run()
        let vm = battle(r)
        vm.answer(keyId: wrongKey(vm), now: 1)
        XCTAssertEqual(vm.phase, .awaitingContinue)
    }

    func testZeroHeartsAreLostAtOnceWhenNoReviveIsAllowed() {
        let (r, _) = run(daily: true)
        let vm = battle(r)
        vm.answer(keyId: wrongKey(vm), now: 1)
        XCTAssertEqual(vm.phase, .lost)
    }

    func testRevivingRestoresAHeartAsksTheSameNoteAndRestartsTheClock() {
        let (r, wallet) = run(hearts: 1)
        let vm = battle(r)
        let question = vm.currentQuestion
        vm.answer(keyId: wrongKey(vm), now: 1)
        XCTAssertTrue(vm.revive(.heart, now: 10))
        XCTAssertEqual(vm.phase, .playing)
        XCTAssertEqual(vm.hearts, 1)
        XCTAssertEqual(vm.currentQuestion, question)
        XCTAssertNil(vm.revealKeyId)
        XCTAssertEqual(wallet.heartsUsed, 1)
        // The same press can't revive twice.
        XCTAssertFalse(vm.revive(.heart, now: 11))
        XCTAssertEqual(wallet.heartsUsed, 1)
    }

    func testGivingUpLosesTheBattleAndPaysNothing() {
        let (r, wallet) = run(hearts: 1)
        let vm = battle(r)
        vm.answer(keyId: wrongKey(vm), now: 1)
        vm.giveUp()
        XCTAssertEqual(vm.phase, .lost)
        XCTAssertEqual(wallet.heartsUsed + wallet.coinsSpent, 0)
    }

    func testAThirdZeroHeartsIsLostAndAWonRunAfterARevivePaysOneStarAtMost() {
        let (r, _) = run(coins: 500)
        let vm = battle(r)
        vm.answer(keyId: wrongKey(vm), now: 1)
        vm.revive(.coins, now: 2)
        vm.answer(keyId: wrongKey(vm), now: 3)
        vm.revive(.coins, now: 4)
        vm.answer(keyId: wrongKey(vm), now: 5)
        XCTAssertEqual(vm.phase, .lost, "max two revives")

        let (r2, _) = run(coins: 500)
        let win = battle(r2, hearts: 3)
        for _ in 0..<2 { win.answer(keyId: win.currentQuestion, now: 1) }
        for t in [2.0, 4.0, 6.0] {
            win.answer(keyId: wrongKey(win), now: t)
            win.step(now: t + 1)   // the right key is revealed for a moment; answers wait for it to end
        }
        XCTAssertEqual(win.phase, .awaitingContinue)
        win.revive(.coins, now: 8)
        for _ in 0..<3 { win.answer(keyId: win.currentQuestion, now: 9) }
        XCTAssertEqual(win.phase, .won)
        XCTAssertEqual(win.stars, 1)
    }

    // MARK: Echo

    private func echo(_ run: ReviveRun?) -> EchoViewModel {
        let config = EchoConfig(pool: [5, 6, 7, 8, 9], roundsToClear: 3, startLength: 2, maxLength: 8,
                                glowDuringPlayback: true, useSongSnippets: false, hearts: 1, seed: 1)
        return EchoViewModel(config: config, reviveRun: run, songs: [], soundPlayer: { _ in }, soundStopper: { _ in })
    }

    private func reachYourTurn(_ vm: EchoViewModel) -> CFTimeInterval {
        vm.start(now: 0)
        var t = 0.0
        while case .listening = vm.phase { t += 0.05; vm.step(now: t) }
        return t
    }

    func testEchoWaitsForTheSheetThenReplaysTheSamePhraseAfterARevive() {
        let (r, wallet) = run(coins: 200)
        let vm = echo(r)
        var t = reachYourTurn(vm)
        let phrase = vm.phrase
        vm.answer(keyId: phrase[0] == 9 ? 5 : 9, now: t)
        XCTAssertEqual(vm.phase, .awaitingContinue)
        XCTAssertTrue(vm.revive(.coins, now: t))
        XCTAssertEqual(wallet.coinsSpent, 50)
        XCTAssertEqual(vm.hearts, 1)
        t += EchoViewModel.pauseAfterMistake + 0.1
        vm.step(now: t)
        XCTAssertEqual(vm.phrase, phrase)
        guard case .listening = vm.phase else { return XCTFail("the phrase should play again") }
    }

    func testEchoGiveUpIsLost() {
        let (r, _) = run()
        let vm = echo(r)
        let t = reachYourTurn(vm)
        vm.answer(keyId: vm.phrase[0] == 9 ? 5 : 9, now: t)
        vm.giveUp()
        XCTAssertEqual(vm.phase, .lost)
    }

    // MARK: Quiz

    private func quiz(_ run: ReviveRun?) -> QuizViewModel {
        let songs = [
            QuizSong(title: "A", keyIds: [5, 6, 7, 8, 9, 10], onsets: (0..<6).map { Double($0) * 0.5 }, isSolemn: false),
            QuizSong(title: "B", keyIds: [9, 9, 10, 9, 12, 11], onsets: (0..<6).map { Double($0) * 0.6 }, isSolemn: false),
            QuizSong(title: "C", keyIds: [12, 11, 10, 9, 8, 7], onsets: (0..<6).map { Double($0) * 0.7 }, isSolemn: false),
            QuizSong(title: "D", keyIds: [5, 7, 9, 12, 9, 7], onsets: (0..<6).map { Double($0) * 0.4 }, isSolemn: false),
        ]
        let config = QuizConfig(variant: .guessSong, questionCount: 4, hearts: 1, seed: 7)
        return QuizViewModel(config: config, reviveRun: run, songs: songs, soundPlayer: { _ in }, soundStopper: { _ in })
    }

    func testQuizWaitsAfterTheWrongAnswerFeedbackAndGoesOnToTheNextQuestionAfterARevive() {
        let (r, wallet) = run(hearts: 1)
        let vm = quiz(r)
        vm.start(now: 0)
        let wrong = (vm.question!.correctIndex + 1) % 4
        vm.answer(wrong, now: 1)
        vm.step(now: 1 + QuizViewModel.pauseAfterWrong + 0.1)
        XCTAssertEqual(vm.phase, .awaitingContinue)
        XCTAssertTrue(vm.revive(.heart, now: 5))
        XCTAssertEqual(wallet.heartsUsed, 1)
        XCTAssertEqual(vm.hearts, 1)
        XCTAssertEqual(vm.questionIndex, 1)
        guard case .listening = vm.phase else { return XCTFail("the next question should start") }
    }

    func testQuizWithoutARunStillEndsAtZeroHearts() {
        let vm = quiz(nil)
        vm.start(now: 0)
        vm.answer((vm.question!.correctIndex + 1) % 4, now: 1)
        vm.step(now: 1 + QuizViewModel.pauseAfterWrong + 0.1)
        XCTAssertEqual(vm.phase, .lost)
    }
}

final class ReviveRecordingTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var submitted: [[LeaderboardScore]] = []
    private var recorder: ResultRecorder!

    override func setUp() {
        super.setUp()
        suiteName = "ReviveRecording-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        submitted = []
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] }, submitScores: { [unowned self] in self.submitted.append($0) })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func rush(revives: Int) -> PlayResult {
        PlayResult(request: PlayRequest(kind: .rush), didWin: false, stars: 0, score: 300, accuracy: nil, maxCombo: 9,
                   perfect: 0, great: 0, good: 0, miss: 0, wrong: 0, correctCount: 20, revivesUsed: revives)
    }

    func testARevivedRushRunCountsLocallyButIsNotSentToGameCenter() {
        recorder.record(rush(revives: 1))
        XCTAssertEqual(progress.rushHighScore, 300)
        XCTAssertTrue(submitted.isEmpty)
    }

    func testAnUnrevivedRushRunIsSentAsBefore() {
        recorder.record(rush(revives: 0))
        XCTAssertEqual(submitted.count, 1)
    }

    func testAWonRunAfterARevivePaysAtMostOneStar() {
        let config = QuizConfig(variant: .guessSong, questionCount: 4, hearts: 3, seed: 7)
        let request = PlayRequest(kind: .quiz(config), campaignStageId: "c1-01")
        let revived = PlayResult(request: request, didWin: true, stars: 3, score: 4, accuracy: nil, maxCombo: 4,
                                 perfect: 0, great: 0, good: 0, miss: 0, wrong: 0, correctCount: 4, revivesUsed: 1)
        recorder.record(revived)
        XCTAssertEqual(progress.stageStars("c1-01"), 1)
    }
}
