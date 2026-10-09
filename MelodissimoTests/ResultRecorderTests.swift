import XCTest
@testable import Melodissimo

final class ResultRecorderTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var recorder: ResultRecorder!
    private var evaluations = 0
    private var unlocked: [String] = []

    private let songId = "berkibarlah-benderaku"
    private var songTitle: String { SongLibrary.song(id: songId)!.title }

    override func setUp() {
        super.setUp()
        suiteName = "ResultRecorderTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        evaluations = 0
        unlocked = []
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [unowned self] in
            self.evaluations += 1
            return self.unlocked
        })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func request(_ mode: StageMode) -> PlayRequest {
        PlayRequest(kind: .song(songId: songId, mode: mode, speed: 1, isBoss: false, isSolemn: false, noteLimit: nil))
    }

    private func perform(score: Int = 10_000, accuracy: Double = 97, stars: Int = 3, combo: Int = 40,
                         perfect: Int = 70, great: Int = 4, good: Int = 0, miss: Int = 0, wrong: Int = 0) -> PlayResult {
        PlayResult(request: request(.perform), didWin: stars > 0, stars: stars, score: score, accuracy: accuracy,
                   maxCombo: combo, perfect: perfect, great: great, good: good, miss: miss, wrong: wrong)
    }

    // MARK: Perform

    func testFirstPerformRecordsBestsStarsAndStats() {
        let summary = recorder.record(perform(score: 12_000, accuracy: 96.5, stars: 3, combo: 50))
        XCTAssertEqual(progress.songBestScore(songId), 12_000)
        XCTAssertEqual(progress.songBestAccuracy(songId), 96.5)
        XCTAssertEqual(progress.songStars(songId), 3)
        XCTAssertEqual(progress.statSongsPerformed, 1)
        XCTAssertEqual(progress.bestCombo, 50)
        XCTAssertEqual(progress.currentStreak, 1, "playing counts towards the daily streak")
        XCTAssertTrue(summary.isNewBest)
        XCTAssertEqual(summary.newStars, 3)
        XCTAssertEqual(summary.coins, 0)
        XCTAssertEqual(evaluations, 1)
    }

    func testABetterRunOnlyRaisesTheBests() {
        recorder.record(perform(score: 8_000, accuracy: 80, stars: 2, combo: 20))
        let worse = recorder.record(perform(score: 5_000, accuracy: 60, stars: 1, combo: 10))
        XCTAssertEqual(progress.songBestScore(songId), 8_000)
        XCTAssertEqual(progress.songBestAccuracy(songId), 80)
        XCTAssertEqual(progress.songStars(songId), 2)
        XCTAssertEqual(progress.bestCombo, 20)
        XCTAssertFalse(worse.isNewBest)
        XCTAssertEqual(worse.newStars, 0)
        XCTAssertEqual(progress.statSongsPerformed, 2, "every performance counts, good or bad")

        let better = recorder.record(perform(score: 9_000, accuracy: 85, stars: 3, combo: 25))
        XCTAssertTrue(better.isNewBest)
        XCTAssertEqual(better.newStars, 1, "only the stars above the old best are new")
        XCTAssertEqual(progress.songStars(songId), 3)
    }

    func testAZeroStarRunStillCountsButEarnsNothingNew() {
        let summary = recorder.record(perform(score: 300, accuracy: 20, stars: 0, combo: 1, perfect: 1, miss: 70))
        XCTAssertEqual(progress.songStars(songId), 0)
        XCTAssertEqual(summary.newStars, 0)
        XCTAssertTrue(summary.isNewBest, "any first score is a best")
        XCTAssertEqual(progress.statSongsPerformed, 1)
        XCTAssertFalse(defaults.bool(forKey: songTitle))
    }

    func testThreeStarsAlsoSetTheLegacyTrophy() {
        recorder.record(perform(stars: 2))
        XCTAssertFalse(defaults.bool(forKey: songTitle))
        recorder.record(perform(stars: 3))
        XCTAssertTrue(defaults.bool(forKey: songTitle), "keyed by the exact song title, as the trophy shelf reads it")
    }

    func testFullComboIsFlaggedAndCountedOncePerSong() {
        recorder.record(perform(miss: 0, wrong: 0))
        XCTAssertTrue(progress.isSongFullCombo(songId))
        XCTAssertEqual(progress.statFullCombos, 1)
        recorder.record(perform(miss: 0, wrong: 0))
        XCTAssertEqual(progress.statFullCombos, 1, "the same song's full combo isn't counted twice")
    }

    func testAMissOrAWrongPressIsNotAFullCombo() {
        recorder.record(perform(miss: 1))
        recorder.record(perform(wrong: 2))
        XCTAssertFalse(progress.isSongFullCombo(songId))
        XCTAssertEqual(progress.statFullCombos, 0)
    }

    func testUnlockedAchievementsAreReported() {
        unlocked = ["Panggung Pertama"]
        let summary = recorder.record(perform())
        XCTAssertEqual(summary.newAchievements, ["Panggung Pertama"])
    }

    // MARK: Practice and Listen

    func testFinishingPracticeUnlocksPerformWithoutScoring() {
        let result = PlayResult(request: request(.practice), didWin: true, stars: 0, score: 0, accuracy: nil,
                                maxCombo: 0, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        let summary = recorder.record(result)
        XCTAssertTrue(progress.isSongPracticed(songId))
        XCTAssertEqual(progress.songBestScore(songId), 0)
        XCTAssertEqual(progress.statSongsPerformed, 0)
        XCTAssertFalse(summary.isNewBest)
        XCTAssertEqual(progress.currentStreak, 1)
    }

    func testListeningRecordsNothingAtAll() {
        let result = PlayResult(request: request(.listen), didWin: true, stars: 0, score: 0, accuracy: nil,
                                maxCombo: 0, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        recorder.record(result)
        XCTAssertFalse(progress.isSongPracticed(songId))
        XCTAssertEqual(progress.currentStreak, 0, "listening doesn't count as playing today")
        XCTAssertEqual(evaluations, 0)
    }

    func testRecordingNeverTouchesOtherSongs() {
        recorder.record(perform())
        XCTAssertEqual(progress.songStars("merah-putih"), 0)
        XCTAssertFalse(progress.isSongPracticed("merah-putih"))
    }

    func testWritesGoToTheInjectedStoreOnly() {
        let before = UserDefaults.standard.integer(forKey: "song_stars_\(songId)")
        recorder.record(perform())
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "song_stars_\(songId)"), before)
        XCTAssertEqual(progress.songStars(songId), 3)
    }
}

final class RushRecordingTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var recorder: ResultRecorder!

    override func setUp() {
        super.setUp()
        suiteName = "RushRecordingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func rush(score: Int, combo: Int = 12) -> PlayResult {
        PlayResult(request: PlayRequest(kind: .rush), didWin: false, stars: 0, score: score, accuracy: nil,
                   maxCombo: combo, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
    }

    func testTheFirstScoreIsAHighScore() {
        XCTAssertEqual(progress.rushHighScore, 0)
        let summary = recorder.record(rush(score: 240))
        XCTAssertTrue(summary.isNewBest)
        XCTAssertEqual(progress.rushHighScore, 240)
        XCTAssertEqual(defaults.integer(forKey: "rush_highScore"), 240)
    }

    func testOnlyABetterScoreReplacesIt() {
        recorder.record(rush(score: 500))
        XCTAssertFalse(recorder.record(rush(score: 300)).isNewBest)
        XCTAssertFalse(recorder.record(rush(score: 500)).isNewBest, "tying it isn't a new high score")
        XCTAssertEqual(progress.rushHighScore, 500)
        XCTAssertTrue(recorder.record(rush(score: 510)).isNewBest)
        XCTAssertEqual(progress.rushHighScore, 510)
    }

    func testAZeroScoreIsNeverAHighScore() {
        XCTAssertFalse(recorder.record(rush(score: 0)).isNewBest)
        XCTAssertEqual(progress.rushHighScore, 0)
    }

    func testRushStillCountsForComboAndStreak() {
        recorder.record(rush(score: 100, combo: 17))
        XCTAssertEqual(progress.bestCombo, 17)
        XCTAssertEqual(progress.currentStreak, 1)
    }

    func testRushDoesNotTouchSongOrClassicProgress() {
        recorder.record(rush(score: 100))
        XCTAssertEqual(progress.statSongsPerformed, 0)
        XCTAssertEqual(progress.highestUnlockedLevel, 0)
    }
}

final class EchoRecordingTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var recorder: ResultRecorder!

    override func setUp() {
        super.setUp()
        suiteName = "EchoRecordingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func echo(rounds: Int, endless: Bool, won: Bool = false) -> PlayResult {
        let config = EchoConfig(pool: [5, 6, 7], roundsToClear: endless ? nil : 3, seed: 1)
        return PlayResult(request: PlayRequest(kind: .echo(config)), didWin: won, stars: won ? 3 : 0, score: rounds,
                          accuracy: nil, maxCombo: 0, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
    }

    func testAnEndlessRunSetsTheHighScoreAndTheBestRoundsStat() {
        let summary = recorder.record(echo(rounds: 7, endless: true))
        XCTAssertTrue(summary.isNewBest)
        XCTAssertEqual(progress.echoHighScore, 7)
        XCTAssertEqual(progress.statEchoBestRounds, 7)
        XCTAssertEqual(defaults.integer(forKey: "echo_highScore"), 7)
        XCTAssertEqual(defaults.integer(forKey: "stat_echoBestRounds"), 7)
    }

    func testOnlyABetterEndlessRunReplacesTheHighScore() {
        recorder.record(echo(rounds: 9, endless: true))
        XCTAssertFalse(recorder.record(echo(rounds: 5, endless: true)).isNewBest)
        XCTAssertFalse(recorder.record(echo(rounds: 9, endless: true)).isNewBest)
        XCTAssertEqual(progress.echoHighScore, 9)
        XCTAssertTrue(recorder.record(echo(rounds: 10, endless: true)).isNewBest)
    }

    func testACampaignEchoFeedsTheStatButNotTheEndlessHighScore() {
        let summary = recorder.record(echo(rounds: 5, endless: false, won: true))
        XCTAssertFalse(summary.isNewBest)
        XCTAssertEqual(progress.echoHighScore, 0)
        XCTAssertEqual(progress.statEchoBestRounds, 5, "any Echo counts towards \"10 rounds in Echo\"")
    }

    func testTheBestRoundsStatNeverGoesDown() {
        recorder.record(echo(rounds: 8, endless: true))
        recorder.record(echo(rounds: 3, endless: false))
        XCTAssertEqual(progress.statEchoBestRounds, 8)
    }

    func testEchoCountsForTheStreak() {
        recorder.record(echo(rounds: 2, endless: true))
        XCTAssertEqual(progress.currentStreak, 1)
    }
}
