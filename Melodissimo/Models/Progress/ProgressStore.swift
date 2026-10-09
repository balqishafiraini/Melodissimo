//
//  ProgressStore.swift
//  Melodissimo
//
//  Stores per-level best scores and derives stars + level unlocking.
//  Backed by UserDefaults to stay consistent with the rest of the app.
//

import Foundation

class ProgressStore: ObservableObject {

    static let shared = ProgressStore()

    private let defaults = UserDefaults.standard

    // Minimum percentage needed for each star rating.
    static let oneStarThreshold = 60
    static let twoStarThreshold = 80
    static let threeStarThreshold = 100

    // Key used by the existing level menu to decide which levels are unlocked.
    private let unlockedLevelKey = "currentLevel"

    private init() {}

    // MARK: - Best score

    private func scoreKey(category: String, level: Int) -> String {
        "bestScore_\(category)_\(level)"
    }

    /// Best percentage score the player has achieved on a level (0 if never played).
    func bestScore(category: String, level: Int) -> Int {
        defaults.integer(forKey: scoreKey(category: category, level: level))
    }

    /// Stores a score, keeping only the highest value seen for that level.
    func recordScore(category: String, level: Int, score: Int) {
        let key = scoreKey(category: category, level: level)
        if score > defaults.integer(forKey: key) {
            defaults.set(score, forKey: key)
            objectWillChange.send()
        }
    }

    // MARK: - Stars

    /// Number of stars (0...3) for a given percentage score.
    func stars(forScore score: Int) -> Int {
        if score >= Self.threeStarThreshold { return 3 }
        if score >= Self.twoStarThreshold { return 2 }
        if score >= Self.oneStarThreshold { return 1 }
        return 0
    }

    /// Number of stars (0...3) earned on a level based on its best score.
    func stars(category: String, level: Int) -> Int {
        stars(forScore: bestScore(category: category, level: level))
    }

    /// Total stars earned across a range of levels in a category.
    func totalStars(category: String, levels: ClosedRange<Int>) -> Int {
        levels.reduce(0) { $0 + stars(category: category, level: $1) }
    }

    // MARK: - Unlocking

    /// Highest level the player has cleared. The level menu unlocks this + 1.
    var highestUnlockedLevel: Int {
        defaults.integer(forKey: unlockedLevelKey)
    }

    /// Marks a level as cleared so the next one unlocks.
    func unlock(upToLevel level: Int) {
        if level > highestUnlockedLevel {
            defaults.set(level, forKey: unlockedLevelKey)
        }
    }

    // MARK: - Combo

    private let bestComboKey = "bestCombo"

    /// Longest streak of correct taps the player has ever chained.
    var bestCombo: Int {
        defaults.integer(forKey: bestComboKey)
    }

    func recordCombo(_ combo: Int) {
        if combo > bestCombo {
            defaults.set(combo, forKey: bestComboKey)
            objectWillChange.send()
        }
    }

    // MARK: - Daily streak

    private let currentStreakKey = "currentStreak"
    private let longestStreakKey = "longestStreak"
    private let lastPlayedKey = "lastPlayedDate"

    var currentStreak: Int {
        defaults.integer(forKey: currentStreakKey)
    }

    var longestStreak: Int {
        defaults.integer(forKey: longestStreakKey)
    }

    /// Call when the player finishes a quiz. Advances the daily streak:
    /// +1 if the last play was yesterday, reset to 1 if a day was skipped,
    /// unchanged if they already played today.
    func registerPlayToday(now: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        if let last = defaults.object(forKey: lastPlayedKey) as? Date {
            let lastDay = calendar.startOfDay(for: last)
            if lastDay == today { return }
            let dayDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            defaults.set(dayDiff == 1 ? currentStreak + 1 : 1, forKey: currentStreakKey)
        } else {
            defaults.set(1, forKey: currentStreakKey)
        }

        if currentStreak > longestStreak {
            defaults.set(currentStreak, forKey: longestStreakKey)
        }
        defaults.set(today, forKey: lastPlayedKey)
        objectWillChange.send()
    }

    // MARK: - Stats (used by achievements)

    /// Highest level cleared, i.e. how many levels are done.
    var clearedLevelCount: Int {
        highestUnlockedLevel
    }

    /// Number of levels in a category earned with a perfect (3-star) score.
    func perfectLevelCount(category: String, levels: ClosedRange<Int>) -> Int {
        levels.reduce(0) { $0 + (bestScore(category: category, level: $1) >= Self.threeStarThreshold ? 1 : 0) }
    }
}
