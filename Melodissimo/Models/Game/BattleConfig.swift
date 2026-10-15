//
//  BattleConfig.swift
//  Melodissimo
//

import Foundation

/// Everything a Note Battle needs to know: which notes to ask, how many, how fast.
struct BattleConfig: Hashable {
    /// Key ids of the notes this battle is about.
    var newPool: [Int]
    /// Key ids of earlier notes mixed in for review.
    var reviewPool: [Int] = []
    /// Probability of drawing from `newPool` when `reviewPool` isn't empty.
    var newWeight = 0.7
    /// How many correct answers defeat the monster. `Int.max` means endless (Melody Rush).
    var questionCount: Int
    /// Seconds allowed per note; `nil` means no timer. In an endless battle this is the starting
    /// interval, which shrinks as the player scores.
    var timePerNote: Double?
    var hearts = 3
    /// Boss battles shrink the timer 5 % per correct answer.
    var isBoss = false
    /// Classic levels: the exact question sequence (`LevelModel.answer`).
    var fixedQuestions: [Int]? = nil
    var seed: UInt64

    static let endless = Int.max
    /// Melody Rush starts at 2.5 s per note, gets 8 % shorter every 10 correct answers, down to 0.8 s.
    static let rushStartInterval = 2.5
    static let rushMinimumInterval = 0.8
    /// A boss battle never shrinks the timer below this.
    static let bossMinimumTime = 0.8

    var isEndless: Bool { questionCount == BattleConfig.endless && fixedQuestions == nil }

    /// How many questions the monster has to survive.
    var totalQuestions: Int { fixedQuestions?.count ?? questionCount }

    /// Melody Rush: endless, 3 hearts, starts at 2.5 s per note and speeds up.
    static func rush(pool: [Int] = NoteCatalog.whiteKeyIDs, seed: UInt64) -> BattleConfig {
        BattleConfig(newPool: pool,
                     questionCount: endless,
                     timePerNote: rushStartInterval,
                     seed: seed)
    }

    /// One of the 100 classic notation levels: its exact question sequence, no timer on levels 1–10,
    /// then `max(3, 6 − level × 0.03)` seconds a note, and every 5th level is a boss.
    static func classic(levelNo: Int, answers: [Int]) -> BattleConfig {
        BattleConfig(newPool: Array(Set(answers)).sorted(),
                     questionCount: answers.count,
                     timePerNote: levelNo <= 10 ? nil : max(3, 6 - Double(levelNo) * 0.03),
                     isBoss: levelNo % 5 == 0,
                     fixedQuestions: answers,
                     seed: UInt64(max(levelNo, 0)))
    }

    /// Seconds the player gets for the next note after `correct` right answers, or `nil` without a timer.
    /// Endless battles speed up 8 % every 10 answers (never below 0.8 s); boss battles shrink 5 % per answer.
    func timeLimit(afterCorrect correct: Int) -> Double? {
        guard let base = timePerNote else { return nil }
        if isEndless {
            return max(BattleConfig.rushMinimumInterval, base * pow(0.92, Double(correct / 10)))
        }
        if isBoss {
            return max(BattleConfig.bossMinimumTime, base * pow(0.95, Double(correct)))
        }
        return base
    }
}
