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
    /// Daily challenge: a flat reward plus a bonus for each day of the streak, up to a cap.
    static let dailyBase = 50
    static let dailyPerStreakDay = 10
    static let dailyStreakCap = 5

    /// A **won** stage or song: stars above the previous best, the first-clear bonuses and the replay
    /// consolation when nothing improved.
    static func clear(newStars: Int, isFirstStageClear: Bool, isFirstBossClear: Bool) -> Int {
        var coins = max(0, newStars) * perNewStar
        if isFirstStageClear { coins += firstClear }
        if isFirstBossClear { coins += firstBossClear }
        if newStars <= 0, !isFirstStageClear { coins += replayClear }
        return coins
    }

    static func rush(correctAnswers: Int) -> Int {
        max(0, correctAnswers) / rushAnswersPerCoin
    }

    static func echoEndless(rounds: Int) -> Int {
        max(0, rounds) * perEchoRound
    }

    static func daily(streak: Int) -> Int {
        dailyBase + dailyPerStreakDay * min(max(streak, 0), dailyStreakCap)
    }
}
