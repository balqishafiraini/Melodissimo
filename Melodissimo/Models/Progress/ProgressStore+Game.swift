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

    /// Song bosses beaten for the first time (feeds "Pemburu Fals").
    var statBossesDefeated: Int { defaults.integer(forKey: "stat_bossesDefeated") }

    func incrementBossesDefeated() {
        defaults.set(statBossesDefeated + 1, forKey: "stat_bossesDefeated")
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

    // MARK: - Coins

    /// Every coin ever earned. Only ever increases, so two devices can merge with `max`.
    var coinsEarnedTotal: Int { defaults.integer(forKey: "coins_earnedTotal") }

    /// Every coin ever spent. Only ever increases.
    var coinsSpentTotal: Int { defaults.integer(forKey: "coins_spentTotal") }

    /// What the player can spend now.
    var coinBalance: Int { max(0, coinsEarnedTotal - coinsSpentTotal) }

    func earn(_ amount: Int) {
        guard amount > 0 else { return }
        defaults.set(coinsEarnedTotal + amount, forKey: "coins_earnedTotal")
        objectWillChange.send()
    }

    /// Takes `amount` from the balance. Returns `false`, changing nothing, when there isn't enough.
    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard amount > 0, amount <= coinBalance else { return false }
        defaults.set(coinsSpentTotal + amount, forKey: "coins_spentTotal")
        objectWillChange.send()
        return true
    }

    // MARK: - Daily challenge

    private func dailyDoneKey(_ dateKey: String) -> String {
        "daily_done_\(dateKey)"
    }

    /// Whether the challenge of that date (`yyyyMMdd`) has been won, so its reward is taken.
    func isDailyDone(_ dateKey: String) -> Bool {
        defaults.bool(forKey: dailyDoneKey(dateKey))
    }

    /// Marks the date's challenge as won. Returns `true` the first time only, which is when it pays.
    @discardableResult
    func completeDaily(_ dateKey: String) -> Bool {
        guard !isDailyDone(dateKey) else { return false }
        defaults.set(true, forKey: dailyDoneKey(dateKey))
        objectWillChange.send()
        return true
    }

    /// What the daily streak will be once the player plays today: one more than now if the last play
    /// was yesterday, 1 after a gap or a first play, unchanged if they already played today.
    func streakAfterPlayingToday(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let last = defaults.object(forKey: "lastPlayedDate") as? Date else { return 1 }
        let today = calendar.startOfDay(for: now)
        let lastDay = calendar.startOfDay(for: last)
        if lastDay == today { return max(currentStreak, 1) }
        let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return gap == 1 ? currentStreak + 1 : 1
    }

    // MARK: - Story cards

    private func storySeenKey(_ id: String) -> String {
        "story_seen_\(id)"
    }

    /// Whether a story card (or the Tour Complete certificate) has already been shown.
    func isStorySeen(_ id: String) -> Bool {
        defaults.bool(forKey: storySeenKey(id))
    }

    func markStorySeen(_ id: String) {
        defaults.set(true, forKey: storySeenKey(id))
        objectWillChange.send()
    }

    /// The story cards to show on the map now, in story order.
    var pendingStoryCards: [StoryCard] {
        StoryCatalog.pending(currentChapter: currentStage.chapter, stars: stageStars, seen: isStorySeen)
    }

    /// Whether the Tour Complete certificate is waiting to be shown.
    var isCertificatePending: Bool {
        StoryCatalog.shouldShowCertificate(stars: stageStars, seen: isStorySeen)
    }

    /// When the finale first earned a star, printed on the certificate. `nil` until the tour is done.
    var tourCompletedAt: Date? {
        let seconds = defaults.double(forKey: "stat_tourCompletedAt")
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    /// Remembers the day the tour was completed. Only the first call counts.
    func recordTourCompleted(on date: Date = Date()) {
        guard tourCompletedAt == nil else { return }
        defaults.set(date.timeIntervalSince1970, forKey: "stat_tourCompletedAt")
        objectWillChange.send()
    }

    /// Every stage has at least one star.
    var isTourComplete: Bool {
        CampaignCatalog.allStages.allSatisfy { stageStars($0.id) >= 1 }
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
