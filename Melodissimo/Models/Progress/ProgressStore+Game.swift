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

    /// Keeps the highest Perform score. Returns `true` when `score` beat the previous best.
    @discardableResult
    func recordSongScore(_ songId: String, score: Int) -> Bool {
        guard score > songBestScore(songId) else { return false }
        defaults.set(score, forKey: songKey("bestScore", songId))
        objectWillChange.send()
        return true
    }

    func recordSongAccuracy(_ songId: String, accuracy: Double) {
        if accuracy > songBestAccuracy(songId) {
            defaults.set(accuracy, forKey: songKey("bestAccuracy", songId))
            objectWillChange.send()
        }
    }

    /// Keeps the best Perform stars (clamped to 0...3). Returns how many stars were gained over the old best.
    @discardableResult
    func recordSongStars(_ songId: String, stars: Int) -> Int {
        let clamped = min(max(stars, 0), 3)
        let previous = songStars(songId)
        guard clamped > previous else { return 0 }
        defaults.set(clamped, forKey: songKey("stars", songId))
        objectWillChange.send()
        return clamped - previous
    }

    /// Marks the song as full-combo'd. Returns `true` the first time only.
    @discardableResult
    func setSongFullCombo(_ songId: String) -> Bool {
        guard !isSongFullCombo(songId) else { return false }
        defaults.set(true, forKey: songKey("fullCombo", songId))
        objectWillChange.send()
        return true
    }

    // MARK: - Melody Rush

    /// The best Melody Rush score.
    var rushHighScore: Int { defaults.integer(forKey: "rush_highScore") }

    /// Keeps the best score. Returns `true` when `score` is a new high score.
    @discardableResult
    func recordRushScore(_ score: Int) -> Bool {
        guard score > rushHighScore else { return false }
        defaults.set(score, forKey: "rush_highScore")
        objectWillChange.send()
        return true
    }

    // MARK: - Echo

    /// The most rounds cleared in one endless Echo run.
    var echoHighScore: Int { defaults.integer(forKey: "echo_highScore") }

    /// Keeps the best endless run. Returns `true` when `rounds` is a new high score.
    @discardableResult
    func recordEchoHighScore(_ rounds: Int) -> Bool {
        guard rounds > echoHighScore else { return false }
        defaults.set(rounds, forKey: "echo_highScore")
        objectWillChange.send()
        return true
    }

    // MARK: - Stats (feed the achievements)

    /// The most rounds cleared in any Echo play, endless or campaign (feeds "Telinga Emas").
    var statEchoBestRounds: Int { defaults.integer(forKey: "stat_echoBestRounds") }

    func recordEchoBestRounds(_ rounds: Int) {
        guard rounds > statEchoBestRounds else { return }
        defaults.set(rounds, forKey: "stat_echoBestRounds")
        objectWillChange.send()
    }

    /// Perform runs finished, over all songs.
    var statSongsPerformed: Int { defaults.integer(forKey: "stat_songsPerformed") }

    /// Songs played through without a miss or wrong press.
    var statFullCombos: Int { defaults.integer(forKey: "stat_fullCombos") }

    func incrementSongsPerformed() {
        defaults.set(statSongsPerformed + 1, forKey: "stat_songsPerformed")
        objectWillChange.send()
    }

    func incrementFullCombos() {
        defaults.set(statFullCombos + 1, forKey: "stat_fullCombos")
        objectWillChange.send()
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

    /// Stores stars for a stage, keeping only the best. Returns how many stars were gained over the old best.
    @discardableResult
    func recordStageStars(_ stageId: String, stars: Int) -> Int {
        let clamped = min(max(stars, 0), 3)
        let previous = stageStars(stageId)
        guard clamped > previous else { return 0 }
        defaults.set(clamped, forKey: stageStarsKey(stageId))
        objectWillChange.send()
        return clamped - previous
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
