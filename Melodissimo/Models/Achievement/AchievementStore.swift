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

    /// A rule describing one achievement and when it unlocks.
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
            Definition(id: "first_star", title: "Langkah Pertama",
                       detail: "Dapatkan bintang pertamamu.", systemImage: "star.fill") {
                self.progress.totalStars(category: "notation", levels: self.notationLevels) >= 1
            },
            Definition(id: "perfectionist", title: "Sempurna!",
                       detail: "Raih 3 bintang di satu level.", systemImage: "sparkles") {
                self.progress.perfectLevelCount(category: "notation", levels: self.notationLevels) >= 1
            },
            Definition(id: "warm_up", title: "Pemanasan",
                       detail: "Selesaikan 10 level.", systemImage: "figure.walk") {
                self.progress.clearedLevelCount >= 10
            },
            Definition(id: "star_collector", title: "Kolektor Bintang",
                       detail: "Kumpulkan 50 bintang.", systemImage: "star.circle.fill") {
                self.progress.totalStars(category: "notation", levels: self.notationLevels) >= 50
            },
            Definition(id: "combo_master", title: "Combo Master",
                       detail: "Capai combo 10 kali berturut-turut.", systemImage: "flame.fill") {
                self.progress.bestCombo >= 10
            },
            Definition(id: "week_streak", title: "Rajin!",
                       detail: "Main 7 hari berturut-turut.", systemImage: "calendar") {
                self.progress.longestStreak >= 7
            },
            Definition(id: "maestro", title: "Maestro",
                       detail: "Taklukkan semua 100 level.", systemImage: "crown.fill") {
                self.progress.clearedLevelCount >= 100
            },
            // The game modes (Song Stage, Echo, the Nusantara Tour, Rush and the shop).
            Definition(id: "first_show", title: "Panggung Pertama",
                       detail: "Tampilkan lagu pertamamu di Panggung Lagu.", systemImage: "music.mic") {
                self.progress.statSongsPerformed >= 1
            },
            Definition(id: "full_combo", title: "Tanpa Cela",
                       detail: "Mainkan satu lagu tanpa meleset atau salah tekan.", systemImage: "checkmark.shield.fill") {
                self.progress.statFullCombos >= 1
            },
            Definition(id: "golden_ear", title: "Telinga Emas",
                       detail: "Capai 10 ronde di Gema.", systemImage: "ear.fill") {
                self.progress.statEchoBestRounds >= 10
            },
            Definition(id: "fals_hunter", title: "Pemburu Fals",
                       detail: "Kalahkan 3 bos Fals.", systemImage: "shield.fill") {
                self.progress.statBossesDefeated >= 3
            },
            Definition(id: "sabang_merauke", title: "Dari Sabang Sampai Merauke",
                       detail: "Tamatkan Tur Nusantara sampai Indonesia Raya.", systemImage: "flag.fill") {
                self.progress.tourCompletedAt != nil
            },
            Definition(id: "rush_100", title: "Kilat",
                       detail: "Raih skor 100 di Melody Rush.", systemImage: "bolt.fill") {
                self.progress.rushHighScore >= 100
            },
            Definition(id: "collector", title: "Kolektor",
                       detail: "Miliki 3 barang dari toko.", systemImage: "bag.fill") {
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

    /// Rebuilds the published list from what's stored.
    func reload() {
        achievements = definitions.map { def in
            Achievement(id: def.id, title: def.title, detail: def.detail,
                        systemImage: def.systemImage, isEarned: defaults.bool(forKey: key(def.id)))
        }
    }

    /// Checks every criterion, persists anything newly unlocked, and returns
    /// the achievements earned during this call (for optional UI feedback).
    @discardableResult
    func evaluate() -> [Achievement] {
        var newlyEarned: [Achievement] = []
        for def in definitions where !defaults.bool(forKey: key(def.id)) && def.isUnlocked() {
            defaults.set(true, forKey: key(def.id))
            newlyEarned.append(Achievement(id: def.id, title: def.title, detail: def.detail,
                                           systemImage: def.systemImage, isEarned: true))
        }
        if !newlyEarned.isEmpty { reload() }
        return newlyEarned
    }
}
