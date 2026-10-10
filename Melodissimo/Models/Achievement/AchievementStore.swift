//
//  AchievementStore.swift
//  Melodissimo
//
//  Defines the achievement catalog, evaluates their unlock criteria against
//  ProgressStore, and persists which ones have been earned.
//

import Foundation

class AchievementStore: ObservableObject {

    static let shared = AchievementStore()

    private let defaults: UserDefaults
    private let progress: ProgressStore

    @Published var achievements: [Achievement] = []

    /// A rule describing one achievement and when it unlocks. `title` and `detail` are English keys in
    /// `Localizable.strings`, looked up (so they follow the language) each time the list is built.
    private struct Definition {
        let id: String
        let title: String
        let detail: String
        let systemImage: String
        let isUnlocked: () -> Bool
    }

    private let notationLevels = 1...100

    private var definitions: [Definition] {
        [
            Definition(id: "first_star", title: "First Step",
                       detail: "Earn your first star.", systemImage: "star.fill") {
                self.progress.totalStars(category: "notation", levels: self.notationLevels) >= 1
            },
            Definition(id: "perfectionist", title: "Perfectionist",
                       detail: "Get 3 stars on one level.", systemImage: "sparkles") {
                self.progress.perfectLevelCount(category: "notation", levels: self.notationLevels) >= 1
            },
            Definition(id: "warm_up", title: "Warm-up",
                       detail: "Finish 10 levels.", systemImage: "figure.walk") {
                self.progress.clearedLevelCount >= 10
            },
            Definition(id: "star_collector", title: "Star Collector",
                       detail: "Collect 50 stars.", systemImage: "star.circle.fill") {
                self.progress.totalStars(category: "notation", levels: self.notationLevels) >= 50
            },
            Definition(id: "combo_master", title: "Combo Master",
                       detail: "Chain a combo of 10 in a row.", systemImage: "flame.fill") {
                self.progress.bestCombo >= 10
            },
            Definition(id: "week_streak", title: "Diligent!",
                       detail: "Play 7 days in a row.", systemImage: "calendar") {
                self.progress.longestStreak >= 7
            },
            Definition(id: "maestro", title: "Maestro",
                       detail: "Beat all 100 levels.", systemImage: "crown.fill") {
                self.progress.clearedLevelCount >= 100
            },
            // The game modes (Song Stage, Echo, the Nusantara Tour, Rush and the shop).
            Definition(id: "first_show", title: "First Show",
                       detail: "Perform your first song in Song Stage.", systemImage: "music.mic") {
                self.progress.statSongsPerformed >= 1
            },
            Definition(id: "full_combo", title: "Flawless",
                       detail: "Play a song with no misses or wrong presses.", systemImage: "checkmark.shield.fill") {
                self.progress.statFullCombos >= 1
            },
            Definition(id: "golden_ear", title: "Golden Ear",
                       detail: "Reach 10 rounds in Echo.", systemImage: "ear.fill") {
                self.progress.statEchoBestRounds >= 10
            },
            Definition(id: "fals_hunter", title: "Fals Hunter",
                       detail: "Defeat 3 Fals bosses.", systemImage: "shield.fill") {
                self.progress.statBossesDefeated >= 3
            },
            Definition(id: "sabang_merauke", title: "From Sabang to Merauke",
                       detail: "Finish the Nusantara Tour through Indonesia Raya.", systemImage: "flag.fill") {
                self.progress.tourCompletedAt != nil
            },
            Definition(id: "rush_100", title: "Lightning",
                       detail: "Score 100 in Melody Rush.", systemImage: "bolt.fill") {
                self.progress.rushHighScore >= 100
            },
            Definition(id: "collector", title: "Collector",
                       detail: "Own 3 shop items.", systemImage: "bag.fill") {
                self.progress.purchasedShopItemCount >= 3
            },
        ]
    }

    /// The app uses `shared`; tests inject a throwaway `UserDefaults` and a `ProgressStore` over the same suite.
    init(defaults: UserDefaults = .standard, progress: ProgressStore = .shared) {
        self.defaults = defaults
        self.progress = progress
        reload()
    }

    private func key(_ id: String) -> String {
        "achievement_\(id)"
    }

    private func achievement(_ def: Definition, isEarned: Bool) -> Achievement {
        Achievement(id: def.id,
                    title: NSLocalizedString(def.title, comment: "Achievement title"),
                    detail: NSLocalizedString(def.detail, comment: "Achievement description"),
                    systemImage: def.systemImage, isEarned: isEarned)
    }

    /// Rebuilds the published list from what's stored.
    func reload() {
        achievements = definitions.map { def in
            achievement(def, isEarned: defaults.bool(forKey: key(def.id)))
        }
    }

    /// Checks every criterion, persists anything newly unlocked, and returns
    /// the achievements earned during this call (for optional UI feedback).
    @discardableResult
    func evaluate() -> [Achievement] {
        var newlyEarned: [Achievement] = []
        for def in definitions where !defaults.bool(forKey: key(def.id)) && def.isUnlocked() {
            defaults.set(true, forKey: key(def.id))
            newlyEarned.append(achievement(def, isEarned: true))
        }
        if !newlyEarned.isEmpty { reload() }
        return newlyEarned
    }
}
