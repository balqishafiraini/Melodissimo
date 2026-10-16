//
//  CoinRewards.swift
//  Melodissimo
//

import Foundation

/// The coin table of the game plan (§2.4) as pure functions, so the amounts live in one place
/// and `ResultRecorder` only has to say what happened.
enum CoinRewards {
    /// Each star above the previous best on a stage or song.
    static let perNewStar = 10
    /// The first star on a campaign stage.
    static let firstClear = 20
    /// Added to the first clear when the stage is a boss.
    static let firstBossClear = 100
    /// A won stage or song that adds no stars.
    static let replayClear = 5
    /// Finishing a song in Practice for the first time.
    static let firstPractice = 15
    /// Melody Rush pays one coin for every five right answers.
    static let rushAnswersPerCoin = 5
    /// Endless Echo pays this much for every round cleared.
    static let perEchoRound = 2
    /// The listening quizzes pay this much for every right answer.
    static let perQuizAnswer = 1
    /// Daily challenge: a flat reward plus a bonus for each day of the streak, up to a cap.
    static let dailyBase = 50
    static let dailyPerStreakDay = 10
    static let dailyStreakCap = 5

    /// A **won** stage or song: stars above the previous best, the first-clear bonuses and the replay
    /// consolation when nothing improved. The amounts come from `Tuning`, with the constants above as defaults.
    static func clear(newStars: Int, isFirstStageClear: Bool, isFirstBossClear: Bool) -> Int {
        var coins = max(0, newStars) * Tuning.int("coins.perNewStar", default: perNewStar)
        if isFirstStageClear { coins += Tuning.int("coins.firstClear", default: firstClear) }
        if isFirstBossClear { coins += Tuning.int("coins.firstBossClear", default: firstBossClear) }
        if newStars <= 0, !isFirstStageClear { coins += Tuning.int("coins.replayClear", default: replayClear) }
        return coins
    }

    static func firstPracticeReward() -> Int {
        Tuning.int("coins.firstPractice", default: firstPractice)
    }

    static func rush(correctAnswers: Int) -> Int {
        max(0, correctAnswers) / max(1, Tuning.int("coins.rushAnswersPerCoin", default: rushAnswersPerCoin, range: 1...1000))
    }

    static func echoEndless(rounds: Int) -> Int {
        max(0, rounds) * Tuning.int("coins.perEchoRound", default: perEchoRound)
    }

    static func quiz(correctAnswers: Int) -> Int {
        max(0, correctAnswers) * Tuning.int("coins.perQuizAnswer", default: perQuizAnswer)
    }

    static func daily(streak: Int) -> Int {
        let cap = Tuning.int("coins.dailyStreakCap", default: dailyStreakCap, range: 0...365)
        return Tuning.int("coins.dailyBase", default: dailyBase)
            + Tuning.int("coins.dailyPerStreakDay", default: dailyPerStreakDay) * min(max(streak, 0), cap)
    }
}
