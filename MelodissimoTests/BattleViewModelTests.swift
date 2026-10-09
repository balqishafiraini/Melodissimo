import XCTest
@testable import Melodissimo

final class BattleViewModelTests: XCTestCase {

    private func config(pool: [Int] = [5, 6, 7],
                        review: [Int] = [],
                        count: Int = 5,
                        timer: Double? = nil,
                        hearts: Int = 3,
                        boss: Bool = false,
                        fixed: [Int]? = nil,
                        seed: UInt64 = 1) -> BattleConfig {
        BattleConfig(newPool: pool, reviewPool: review, questionCount: count, timePerNote: timer,
                     hearts: hearts, isBoss: boss, fixedQuestions: fixed, seed: seed)
    }

    private func wrongKey(for question: Int) -> Int {
        question == 30 ? 31 : 30
    }

    /// Answers `n` questions correctly and returns the questions asked.
    @discardableResult
    private func playCorrect(_ vm: BattleViewModel, _ n: Int, at now: CFTimeInterval = 0) -> [Int] {
        var asked: [Int] = []
        for _ in 0..<n {
            asked.append(vm.currentQuestion)
            vm.answer(keyId: vm.currentQuestion, now: now)
        }
        return asked
    }

    // MARK: SeededRandom

    func testSeededRandomIsDeterministic() {
        var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42), c = SeededRandom(seed: 43)
        let first = (0..<5).map { _ in a.next() }
        XCTAssertEqual(first, (0..<5).map { _ in b.next() })
        XCTAssertNotEqual(first, (0..<5).map { _ in c.next() })
    }

    func testSeededRandomMatchesReferenceSplitMix64() {
        var rng = SeededRandom(seed: 0)
        XCTAssertEqual(rng.next(), 0xe220a8397b1dcdaf)
        XCTAssertEqual(rng.next(), 0x6e789e6aa1b965f4)
        XCTAssertEqual(rng.next(), 0x06c45d188009454f)
    }

    func testSeedFromStringIsStableFNV1a() {
        XCTAssertEqual(SeededRandom.seed(from: ""), 0xcbf29ce484222325)
        XCTAssertEqual(SeededRandom.seed(from: "a"), 0xaf63dc4c8601ec8c)
        XCTAssertEqual(SeededRandom.seed(from: "c2-05"), SeededRandom.seed(from: "c2-05"))
        XCTAssertNotEqual(SeededRandom.seed(from: "c2-05"), SeededRandom.seed(from: "c2-06"))
    }

    // MARK: Questions

    func testSameSeedGivesTheSameQuestions() {
        let endless = BattleConfig.endless
        let a = BattleViewModel(config: config(pool: [5, 6, 7, 8, 9], count: endless, seed: 7))
        let b = BattleViewModel(config: config(pool: [5, 6, 7, 8, 9], count: endless, seed: 7))
        let c = BattleViewModel(config: config(pool: [5, 6, 7, 8, 9], count: endless, seed: 8))
        let questionsA = playCorrect(a, 60), questionsB = playCorrect(b, 60), questionsC = playCorrect(c, 60)
        XCTAssertEqual(questionsA, questionsB)
        XCTAssertNotEqual(questionsA, questionsC)
    }

    func testQuestionsStayInThePools() {
        let vm = BattleViewModel(config: config(pool: [5, 6], review: [10, 11], count: BattleConfig.endless))
        let asked = playCorrect(vm, 200)
        XCTAssertTrue(asked.allSatisfy { [5, 6, 10, 11].contains($0) })
    }

    func testNoImmediateRepeats() {
        for pool in [[5, 6], [5, 6, 7], Array(1...19)] {
            let vm = BattleViewModel(config: config(pool: pool, count: BattleConfig.endless))
            let asked = playCorrect(vm, 1000)
            XCTAssertFalse(zip(asked, asked.dropFirst()).contains { $0 == $1 }, "pool \(pool.count)")
        }
        let mixed = BattleViewModel(config: config(pool: [5, 6], review: [7], count: BattleConfig.endless))
        let asked = playCorrect(mixed, 1000)
        XCTAssertFalse(zip(asked, asked.dropFirst()).contains { $0 == $1 })
    }

    func testASingleNotePoolMayRepeat() {
        let vm = BattleViewModel(config: config(pool: [5], count: 4))
        XCTAssertEqual(playCorrect(vm, 4), [5, 5, 5, 5])
    }

    func testNewAndReviewPoolsAreMixedSeventyThirty() {
        let vm = BattleViewModel(config: config(pool: [5, 6, 7], review: [8, 9, 10, 11], count: BattleConfig.endless, seed: 99))
        let asked = playCorrect(vm, 1000)
        let fromNew = asked.filter { [5, 6, 7].contains($0) }.count
        XCTAssertGreaterThan(fromNew, 600)
        XCTAssertLessThan(fromNew, 800)
    }

    func testFixedQuestionsAreAskedInOrder() {
        let vm = BattleViewModel(config: config(count: 0, fixed: [5, 5, 9, 12, 9]))
        XCTAssertEqual(vm.monsterHP, 5)
        XCTAssertEqual(playCorrect(vm, 5), [5, 5, 9, 12, 9])
        XCTAssertEqual(vm.phase, .won)
    }

    // MARK: Answering

    func testCorrectAnswerHurtsTheMonsterAndBuildsCombo() {
        let vm = BattleViewModel(config: config(count: 3))
        XCTAssertEqual(vm.monsterHP, 3)
        XCTAssertEqual(vm.phase, .playing)
        vm.answer(keyId: vm.currentQuestion, now: 1)
        XCTAssertEqual(vm.monsterHP, 2)
        XCTAssertEqual(vm.combo, 1)
        XCTAssertEqual(vm.score, 10)
        XCTAssertEqual(vm.lastOutcome?.kind, .correct)
        XCTAssertEqual(vm.hearts, 3)
        XCTAssertEqual(vm.damageFraction, 1.0 / 3.0, accuracy: 1e-9)
    }

    func testWrongAnswerCostsAHeartRevealsTheKeyAndAsksTheSameNoteAgain() {
        let vm = BattleViewModel(config: config(count: 3))
        let question = vm.currentQuestion
        vm.answer(keyId: wrongKey(for: question), now: 10)
        XCTAssertEqual(vm.hearts, 2)
        XCTAssertEqual(vm.combo, 0)
        XCTAssertEqual(vm.revealKeyId, question)
        XCTAssertEqual(vm.currentQuestion, question, "same note is asked again")
        XCTAssertEqual(vm.monsterHP, 3)
        XCTAssertEqual(vm.lastOutcome?.kind, .wrong)

        // Presses during the reveal are ignored.
        vm.answer(keyId: wrongKey(for: question), now: 10.3)
        vm.answer(keyId: question, now: 10.5)
        XCTAssertEqual(vm.hearts, 2)
        XCTAssertEqual(vm.monsterHP, 3)

        vm.step(now: 10.79)
        XCTAssertEqual(vm.revealKeyId, question)
        vm.step(now: 10.8)
        XCTAssertNil(vm.revealKeyId)
        XCTAssertEqual(vm.currentQuestion, question)

        vm.answer(keyId: question, now: 11)
        XCTAssertEqual(vm.monsterHP, 2)
        XCTAssertEqual(vm.hearts, 2)
    }

    func testAWrongAnswerResetsComboButKeepsMaxCombo() {
        let vm = BattleViewModel(config: config(count: 10))
        playCorrect(vm, 3)
        vm.answer(keyId: wrongKey(for: vm.currentQuestion), now: 0)
        XCTAssertEqual(vm.combo, 0)
        XCTAssertEqual(vm.maxCombo, 3)
    }

    func testFirstTryCorrectCountIgnoresQuestionsThatNeededARetry() {
        let vm = BattleViewModel(config: config(count: 4))
        vm.answer(keyId: wrongKey(for: vm.currentQuestion), now: 0)   // mistake on question 1
        vm.step(now: 1)
        vm.answer(keyId: vm.currentQuestion, now: 1)                   // …then right
        playCorrect(vm, 3, at: 2)
        XCTAssertEqual(vm.phase, .won)
        XCTAssertEqual(vm.correctCount, 4)
        XCTAssertEqual(vm.firstTryCorrectCount, 3)
        XCTAssertEqual(vm.mistakeCount, 1)
        XCTAssertEqual(vm.firstTryPercent, 75)
    }

    // MARK: Win / lose

    func testWinningGivesStarsEqualToHeartsLeft() {
        let clean = BattleViewModel(config: config(count: 3))
        playCorrect(clean, 3)
        XCTAssertEqual(clean.phase, .won)
        XCTAssertEqual(clean.stars, 3)

        let oneMistake = BattleViewModel(config: config(count: 3))
        oneMistake.answer(keyId: wrongKey(for: oneMistake.currentQuestion), now: 0)
        oneMistake.step(now: 1)
        playCorrect(oneMistake, 3, at: 1)
        XCTAssertEqual(oneMistake.phase, .won)
        XCTAssertEqual(oneMistake.stars, 2)

        let twoMistakes = BattleViewModel(config: config(count: 2))
        for _ in 0..<2 {
            twoMistakes.answer(keyId: wrongKey(for: twoMistakes.currentQuestion), now: 0)
            twoMistakes.step(now: 100)
        }
        playCorrect(twoMistakes, 2, at: 100)
        XCTAssertEqual(twoMistakes.stars, 1)
    }

    func testLosingAllHeartsEndsTheBattleWithNoStars() {
        let vm = BattleViewModel(config: config(count: 5))
        for i in 0..<3 {
            XCTAssertEqual(vm.phase, .playing)
            vm.answer(keyId: wrongKey(for: vm.currentQuestion), now: Double(i) * 10)
            vm.step(now: Double(i) * 10 + 1)
        }
        XCTAssertEqual(vm.hearts, 0)
        XCTAssertEqual(vm.phase, .lost)
        XCTAssertEqual(vm.stars, 0)
        vm.answer(keyId: vm.currentQuestion, now: 100)
        XCTAssertEqual(vm.monsterHP, 5, "no more answers once the battle is over")
    }

    func testNothingHappensAfterWinning() {
        let vm = BattleViewModel(config: config(count: 1))
        playCorrect(vm, 1)
        XCTAssertEqual(vm.phase, .won)
        vm.answer(keyId: wrongKey(for: vm.currentQuestion), now: 5)
        XCTAssertEqual(vm.hearts, 3)
        XCTAssertEqual(vm.phase, .won)
    }

    func testCustomHeartCount() {
        let vm = BattleViewModel(config: config(count: 5, hearts: 1))
        vm.answer(keyId: wrongKey(for: vm.currentQuestion), now: 0)
        XCTAssertEqual(vm.phase, .lost)
    }

    // MARK: Timer

    func testNoTimerMeansNoTimeout() {
        let vm = BattleViewModel(config: config(timer: nil))
        vm.start(now: 0)
        vm.step(now: 10_000)
        XCTAssertEqual(vm.hearts, 3)
        XCTAssertNil(vm.timerFraction(now: 5))
    }

    func testRunningOutOfTimeCountsAsAWrongAnswer() {
        let vm = BattleViewModel(config: config(count: 5, timer: 4))
        let question = vm.currentQuestion
        vm.start(now: 10)
        vm.step(now: 13.9)
        XCTAssertEqual(vm.hearts, 3)
        vm.step(now: 14.0)
        XCTAssertEqual(vm.hearts, 2)
        XCTAssertEqual(vm.lastOutcome?.kind, .timeout)
        XCTAssertEqual(vm.revealKeyId, question)
        XCTAssertEqual(vm.currentQuestion, question)
        XCTAssertEqual(vm.combo, 0)
        XCTAssertNil(vm.timerFraction(now: 14.1), "no timer bar while the answer is revealed")

        vm.step(now: 14.8)                                  // reveal over, timer restarts here
        XCTAssertNil(vm.revealKeyId)
        vm.step(now: 18.7)
        XCTAssertEqual(vm.hearts, 2)
        vm.step(now: 18.8)
        XCTAssertEqual(vm.hearts, 1)
    }

    func testAnsweringRestartsTheTimer() {
        let vm = BattleViewModel(config: config(count: 5, timer: 4))
        vm.start(now: 10)
        vm.answer(keyId: vm.currentQuestion, now: 12)
        vm.step(now: 15.9)
        XCTAssertEqual(vm.hearts, 3)
        vm.step(now: 16.0)
        XCTAssertEqual(vm.hearts, 2)
    }

    func testTimerFractionDrainsTowardsZero() throws {
        let vm = BattleViewModel(config: config(count: 5, timer: 4))
        XCTAssertEqual(try XCTUnwrap(vm.timerFraction(now: 99)), 1, "full until the battle starts")
        vm.start(now: 10)
        XCTAssertEqual(try XCTUnwrap(vm.timerFraction(now: 10)), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(vm.timerFraction(now: 12)), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(vm.timerFraction(now: 20)), 0, accuracy: 1e-9)
    }

    func testTimerDoesNotRunBeforeStart() {
        let vm = BattleViewModel(config: config(count: 5, timer: 4))
        vm.step(now: 1_000)
        XCTAssertEqual(vm.hearts, 3)
    }

    func testBossTimerShrinksFivePercentPerCorrectAnswer() {
        let cfg = config(count: 40, timer: 6, boss: true)
        XCTAssertEqual(cfg.timeLimit(afterCorrect: 0) ?? 0, 6, accuracy: 1e-9)
        XCTAssertEqual(cfg.timeLimit(afterCorrect: 1) ?? 0, 5.7, accuracy: 1e-9)
        XCTAssertEqual(cfg.timeLimit(afterCorrect: 2) ?? 0, 6 * 0.95 * 0.95, accuracy: 1e-9)
        XCTAssertEqual(cfg.timeLimit(afterCorrect: 100) ?? 0, BattleConfig.bossMinimumTime, accuracy: 1e-9)

        let vm = BattleViewModel(config: cfg)
        XCTAssertEqual(vm.currentTimeLimit ?? 0, 6, accuracy: 1e-9)
        playCorrect(vm, 3)
        XCTAssertEqual(vm.currentTimeLimit ?? 0, 6 * pow(0.95, 3), accuracy: 1e-9)
    }

    func testRegularBattlesKeepAConstantTimer() {
        let cfg = config(count: 10, timer: 5)
        XCTAssertEqual(cfg.timeLimit(afterCorrect: 0), 5)
        XCTAssertEqual(cfg.timeLimit(afterCorrect: 9), 5)
        XCTAssertNil(config(timer: nil).timeLimit(afterCorrect: 3))
    }

    // MARK: Melody Rush

    func testRushIntervalScheduleSpeedsUpEightPercentEveryTenAnswers() {
        let rush = BattleConfig.rush(seed: 1)
        XCTAssertTrue(rush.isEndless)
        XCTAssertEqual(rush.hearts, 3)
        XCTAssertEqual(rush.timeLimit(afterCorrect: 0) ?? 0, 2.5, accuracy: 1e-9)
        XCTAssertEqual(rush.timeLimit(afterCorrect: 9) ?? 0, 2.5, accuracy: 1e-9)
        XCTAssertEqual(rush.timeLimit(afterCorrect: 10) ?? 0, 2.3, accuracy: 1e-9)
        XCTAssertEqual(rush.timeLimit(afterCorrect: 19) ?? 0, 2.3, accuracy: 1e-9)
        XCTAssertEqual(rush.timeLimit(afterCorrect: 20) ?? 0, 2.5 * 0.92 * 0.92, accuracy: 1e-9)
        XCTAssertEqual(rush.timeLimit(afterCorrect: 139) ?? 0, 2.5 * pow(0.92, 13), accuracy: 1e-9)
        XCTAssertEqual(rush.timeLimit(afterCorrect: 140) ?? 0, 0.8, accuracy: 1e-9, "13.66 steps down to the floor")
        XCTAssertEqual(rush.timeLimit(afterCorrect: 5_000) ?? 0, 0.8, accuracy: 1e-9)
    }

    func testRushIsEndlessAndScoresTenTimesTheComboMultiplier() {
        let vm = BattleViewModel(config: .rush(seed: 5))
        XCTAssertTrue(vm.isEndless)
        playCorrect(vm, 9)
        XCTAssertEqual(vm.score, 90)
        playCorrect(vm, 1)                                  // the 10th in a row is already ×2
        XCTAssertEqual(vm.score, 110)
        XCTAssertEqual(vm.phase, .playing)
        XCTAssertEqual(vm.damageFraction, 0)
        XCTAssertEqual(vm.currentTimeLimit ?? 0, 2.3, accuracy: 1e-9)
    }

    func testRushMultiplierGoesFromOneToFive() {
        for (combo, expected) in [(0, 1), (9, 1), (10, 2), (20, 3), (30, 4), (40, 5), (99, 5)] {
            XCTAssertEqual(BattleViewModel.multiplier(forCombo: combo), expected, "combo \(combo)")
        }
    }

    func testRushEndsWhenTheThirdHeartIsGone() {
        let vm = BattleViewModel(config: .rush(seed: 5))
        vm.start(now: 0)
        for round in 0..<3 {
            vm.step(now: Double(round) * 10 + 5)            // way past the 2.5 s deadline
            vm.step(now: Double(round) * 10 + 6)            // reveal over
        }
        XCTAssertEqual(vm.hearts, 0)
        XCTAssertEqual(vm.phase, .lost)
    }
}
