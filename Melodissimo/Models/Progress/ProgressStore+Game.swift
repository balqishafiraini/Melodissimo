//
//  ProgressStore+Game.swift
//  Melodissimo
//
//  Progress for the game modes (campaign stages now; songs, coins, shop and settings join later).
//  Same pattern as the rest of `ProgressStore`: plain `UserDefaults` keys, never renamed.
//

import Foundation

extension ProgressStore {

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
