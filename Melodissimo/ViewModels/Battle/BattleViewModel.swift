//
//  BattleViewModel.swift
//  Melodissimo
//

import Foundation
import Combine
import QuartzCore

/// Runs one Note Battle: the monster "shouts" a note, the player plays it.
///
/// A correct answer hurts the monster. A wrong answer (or running out of time) costs a heart,
/// reveals the right key for a moment and then asks **the same note again**, so every win means
/// every note was eventually played right. Like `RhythmEngine`, it never reads the clock itself:
/// every time-based method takes `now` (a `CACurrentMediaTime()` value), so tests can drive it.
final class BattleViewModel: ObservableObject {

    enum Phase: Hashable {
        case playing, won, lost
    }

    /// What just happened, so the view can play the matching animation.
    struct Outcome: Hashable {
        enum Kind: Hashable { case correct, wrong, timeout }
        let kind: Kind
        /// Increases with every outcome, so two equal outcomes in a row still change the value.
        let token: Int
    }

    /// How long the right key stays highlighted after a mistake.
    static let revealDuration = 0.8
    /// Points per correct note, before the combo multiplier.
    static let pointsPerNote = 10

    let config: BattleConfig

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var monsterHP: Int
    @Published private(set) var hearts: Int
    @Published private(set) var combo = 0
    @Published private(set) var maxCombo = 0
    @Published private(set) var score = 0
    /// The key id the player has to play right now.
    @Published private(set) var currentQuestion: Int
    /// Set for `revealDuration` after a mistake: the key to highlight (and play) as a hint.
    @Published private(set) var revealKeyId: Int?
    @Published private(set) var lastOutcome: Outcome?

    /// Questions answered correctly (each question counts once).
    private(set) var correctCount = 0
    /// Questions answered right on the first attempt.
    private(set) var firstTryCorrectCount = 0
    /// Wrong answers and timeouts.
    private(set) var mistakeCount = 0

    private var random: SeededRandom
    private var previousQuestion: Int?
    private var questionsDrawn = 0
    private var currentQuestionHadMistake = false
    private var hasStarted = false
    private var questionStartedAt: CFTimeInterval = 0
    private var revealUntil: CFTimeInterval?
    private var outcomeCounter = 0

    init(config: BattleConfig) {
        self.config = config
        self.monsterHP = config.totalQuestions
        self.hearts = config.hearts
        self.random = SeededRandom(seed: config.seed)
        // Placeholder until the first draw just below.
        self.currentQuestion = config.newPool.first ?? 1
        self.currentQuestion = drawQuestion()
    }

    // MARK: Derived values

    var isEndless: Bool { config.isEndless }

    /// Hearts left when the monster is beaten, 0 otherwise.
    var stars: Int {
        phase == .won ? min(max(hearts, 0), 3) : 0
    }

    /// First-try accuracy for the legacy classic-level score: right-first-time answers over all questions.
    var firstTryPercent: Int {
        let total = config.totalQuestions
        guard total > 0, total != BattleConfig.endless else { return 0 }
        return Int(Double(firstTryCorrectCount) / Double(total) * 100)
    }

    /// Fraction of the monster's health that is gone (0…1); 0 for endless battles.
    var damageFraction: Double {
        guard !isEndless, config.totalQuestions > 0 else { return 0 }
        return Double(config.totalQuestions - monsterHP) / Double(config.totalQuestions)
    }

    var comboMultiplier: Int { BattleViewModel.multiplier(forCombo: combo) }

    /// `1 + min(combo / 10, 4)`: ×1 to ×5.
    static func multiplier(forCombo combo: Int) -> Int {
        1 + min(max(combo, 0) / 10, 4)
    }

    /// Seconds allowed for the current note, or `nil` without a timer.
    var currentTimeLimit: Double? {
        config.timeLimit(afterCorrect: correctCount)
    }

    /// Time left on the current note as a fraction (1 = full, 0 = out); `nil` without a timer
    /// or while the answer is being revealed.
    func timerFraction(now: CFTimeInterval) -> Double? {
        guard phase == .playing, revealUntil == nil, let limit = currentTimeLimit, limit > 0 else { return nil }
        guard hasStarted else { return 1 }
        return min(1, max(0, 1 - (now - questionStartedAt) / limit))
    }

    // MARK: Play

    /// Starts the clock on the first note. Call when the battle appears.
    func start(now: CFTimeInterval) {
        hasStarted = true
        questionStartedAt = now
    }

    /// The player played a key (answers register on finger lift, so this is a key *release*).
    func answer(keyId: Int, now: CFTimeInterval) {
        guard phase == .playing, revealUntil == nil else { return }
        if keyId == currentQuestion {
            registerCorrect(now: now)
        } else {
            registerMistake(kind: .wrong, now: now)
        }
    }

    /// Called every frame (or at 20 Hz): ends the reveal, and turns a missed deadline into a mistake.
    func step(now: CFTimeInterval) {
        if let until = revealUntil, now >= until {
            revealUntil = nil
            revealKeyId = nil
            questionStartedAt = now          // the timer restarts once the hint is gone
        }
        guard hasStarted, phase == .playing, revealUntil == nil, let limit = currentTimeLimit else { return }
        if now - questionStartedAt >= limit {
            registerMistake(kind: .timeout, now: now)
        }
    }

    private func registerCorrect(now: CFTimeInterval) {
        correctCount += 1
        if !currentQuestionHadMistake { firstTryCorrectCount += 1 }
        combo += 1
        if combo > maxCombo { maxCombo = combo }
        score += BattleViewModel.pointsPerNote * BattleViewModel.multiplier(forCombo: combo)
        monsterHP -= 1
        emit(.correct)
        if monsterHP <= 0 {
            phase = .won
            return
        }
        currentQuestion = drawQuestion()
        currentQuestionHadMistake = false
        questionStartedAt = now
    }

    private func registerMistake(kind: Outcome.Kind, now: CFTimeInterval) {
        mistakeCount += 1
        currentQuestionHadMistake = true
        combo = 0
        hearts = max(0, hearts - 1)
        revealKeyId = currentQuestion
        revealUntil = now + BattleViewModel.revealDuration
        emit(kind)
        if hearts == 0 {
            phase = .lost
        }
    }

    private func emit(_ kind: Outcome.Kind) {
        outcomeCounter += 1
        lastOutcome = Outcome(kind: kind, token: outcomeCounter)
    }

    // MARK: Questions

    /// Draws the next question. Never repeats the previous one (unless the pools hold a single note).
    private func drawQuestion() -> Int {
        let question: Int
        if let fixed = config.fixedQuestions, !fixed.isEmpty {
            question = fixed[min(questionsDrawn, fixed.count - 1)]
        } else {
            question = randomQuestion()
        }
        questionsDrawn += 1
        previousQuestion = question
        return question
    }

    private func randomQuestion() -> Int {
        let usingReview = !config.reviewPool.isEmpty
        let pickFromNew = !usingReview || Double.random(in: 0..<1, using: &random) < config.newWeight
        let primary = pickFromNew ? config.newPool : config.reviewPool
        let secondary = pickFromNew ? config.reviewPool : config.newPool

        for pool in [primary, secondary] {
            let candidates = pool.filter { $0 != previousQuestion }
            if let pick = candidates.randomElement(using: &random) {
                return pick
            }
        }
        // Only one note to choose from: a repeat can't be avoided.
        return primary.first ?? secondary.first ?? 1
    }
}
