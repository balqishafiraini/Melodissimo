//
//  ProgressStore+Game.swift
//  Melodissimo
//
//  Progress for the game modes (campaign stages now; songs, coins, shop and settings join later).
//  Same pattern as the rest of `ProgressStore`: plain `UserDefaults` keys, never renamed.
//

import Foundation

extension ProgressStore {

    // MARK: - Songs (Song Stage)

    private func songKey(_ name: String, _ songId: String) -> String {
        "song_\(name)_\(songId)"
    }

    /// Best Perform score.
    func songBestScore(_ songId: String) -> Int {
        defaults.integer(forKey: songKey("bestScore", songId))
    }

    /// Best Perform accuracy, 0–100.
    func songBestAccuracy(_ songId: String) -> Double {
        defaults.double(forKey: songKey("bestAccuracy", songId))
    }

    /// Best Perform stars (0...3), after the speed cap.
    func songStars(_ songId: String) -> Int {
        defaults.integer(forKey: songKey("stars", songId))
    }

    /// Practice finished at least once, which unlocks Perform.
    func isSongPracticed(_ songId: String) -> Bool {
        defaults.bool(forKey: songKey("practiced", songId))
    }

    func setSongPracticed(_ songId: String) {
        guard !isSongPracticed(songId) else { return }
        defaults.set(true, forKey: songKey("practiced", songId))
        objectWillChange.send()
    }

    func isSongFullCombo(_ songId: String) -> Bool {
        defaults.bool(forKey: songKey("fullCombo", songId))
    }

    // MARK: - Settings

    /// Whether key labels are shown while performing (off by default; Practice always starts with them on).
    var labelsInPerform: Bool {
        get { defaults.bool(forKey: "settings_labelsInPerform") }
        set {
            defaults.set(newValue, forKey: "settings_labelsInPerform")
            objectWillChange.send()
        }
    }

    // MARK: - Campaign stages

    private func stageStarsKey(_ stageId: String) -> String {
        "stage_stars_\(stageId)"
    }

    /// Best stars (0...3) earned on a campaign stage.
    func stageStars(_ stageId: String) -> Int {
        defaults.integer(forKey: stageStarsKey(stageId))
    }

    /// Stores stars for a stage, keeping only the best.
    func recordStageStars(_ stageId: String, stars: Int) {
        let clamped = min(max(stars, 0), 3)
        if clamped > stageStars(stageId) {
            defaults.set(clamped, forKey: stageStarsKey(stageId))
            objectWillChange.send()
        }
    }

    /// Total stars over a chapter's stages.
    func chapterStars(_ chapter: Int) -> Int {
        CampaignCatalog.stages(inChapter: chapter).reduce(0) { $0 + stageStars($1.id) }
    }

    /// Total stars over the whole tour.
    var tourStars: Int {
        CampaignCatalog.allStages.reduce(0) { $0 + stageStars($1.id) }
    }

    // MARK: - Chapter unlocking

    private var grantedChapterKey: String { "campaign_grantedChapter" }

    /// The chapter existing-player migration opened (0 = migration hasn't run yet).
    var grantedChapter: Int {
        defaults.integer(forKey: grantedChapterKey)
    }

    func isUnlocked(_ stage: Stage) -> Bool {
        CampaignCatalog.isUnlocked(stage, grantedChapter: grantedChapter, stars: stageStars)
    }

    /// The stage the player is up to (the first open stage without a star).
    var currentStage: Stage {
        CampaignCatalog.currentStage(grantedChapter: grantedChapter, stars: stageStars)
    }

    /// Run once: players who already cleared classic levels start further along the tour
    /// (≥ 20 / 40 / 60 / 80 / 95 levels opens chapter 2 / 3 / 4 / 5 / 6).
    func runMigrationIfNeeded() {
        guard grantedChapter == 0 else { return }
        defaults.set(CampaignCatalog.grantedChapter(forClearedClassicLevels: highestUnlockedLevel), forKey: grantedChapterKey)
        objectWillChange.send()
    }
}
