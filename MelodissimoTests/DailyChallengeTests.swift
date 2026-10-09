import XCTest
@testable import Melodissimo

final class DailyChallengeTests: XCTestCase {

    /// A fixed calendar, so the tests don't depend on the machine's time zone.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func challenge(_ year: Int, _ month: Int, _ day: Int, chapter: Int = 1) -> DailyChallenge {
        DailyChallenge.make(for: date(year, month, day), chapter: chapter, calendar: calendar)!
    }

    // MARK: Date keys and seeds

    func testTheKeyIsTheDateWithoutSeparators() {
        XCTAssertEqual(DailyChallenge.dateKey(for: date(2026, 10, 10), calendar: calendar), "20261010")
        XCTAssertEqual(DailyChallenge.dateKey(for: date(2027, 1, 5), calendar: calendar), "20270105", "zero padded")
    }

    func testTheSeedIsTheDateKeyAsANumber() {
        XCTAssertEqual(challenge(2026, 10, 10).seed, 20_261_010)
    }

    func testTheTimeOfDayDoesNotChangeTheChallenge() {
        let morning = DailyChallenge.make(for: date(2026, 3, 3, hour: 0), chapter: 2, calendar: calendar)
        let night = DailyChallenge.make(for: date(2026, 3, 3, hour: 23), chapter: 2, calendar: calendar)
        XCTAssertEqual(morning, night)
    }

    func testTheSameDateGivesTheSameChallenge() {
        XCTAssertEqual(challenge(2026, 6, 15, chapter: 3), challenge(2026, 6, 15, chapter: 3))
    }

    func testDifferentDatesGetDifferentSeeds() {
        let seeds = (1...28).map { challenge(2026, 2, $0).seed }
        XCTAssertEqual(Set(seeds).count, 28)
    }

    // MARK: Rotation

    func testTheTypeRotatesWithTheDayOfTheYear() {
        // 1 January is day 1 (1 % 3 = 1 → Battle), then Song Sprint, then Echo, and round again.
        XCTAssertEqual(challenge(2026, 1, 1).kind, .battle)
        XCTAssertEqual(challenge(2026, 1, 2).kind, .songSprint)
        XCTAssertEqual(challenge(2026, 1, 3).kind, .echo)
        XCTAssertEqual(challenge(2026, 1, 4).kind, .battle)
    }

    func testEveryTypeComesUpInAnyThreeDays() {
        for start in 1...20 {
            let kinds = Set((0..<3).map { challenge(2026, 5, start + $0).kind })
            XCTAssertEqual(kinds.count, 3, "from 5/\(start)")
        }
    }

    // MARK: Note pool

    func testThePoolIsEverythingTaughtUpToTheChapter() {
        XCTAssertEqual(challenge(2026, 1, 1, chapter: 1).pool, CampaignCatalog.notesTaught(through: 1))
        XCTAssertEqual(challenge(2026, 1, 1, chapter: 4).pool, CampaignCatalog.notesTaught(through: 4))
        XCTAssertEqual(challenge(2026, 1, 1, chapter: 6).pool.count, 32)
    }

    func testTheChapterIsKeptInsideTheTour() {
        XCTAssertEqual(challenge(2026, 1, 1, chapter: 0).pool, CampaignCatalog.notesTaught(through: 1))
        XCTAssertEqual(challenge(2026, 1, 1, chapter: 99).pool, CampaignCatalog.notesTaught(through: 6))
    }

    // MARK: What gets played

    func testEchoIsFiveRoundsOverThePool() throws {
        let day = challenge(2026, 1, 3, chapter: 2)
        guard case .echo(let config)? = day.playKind else { return XCTFail("expected Echo") }
        XCTAssertEqual(config.roundsToClear, 5)
        XCTAssertEqual(config.pool, day.pool)
        XCTAssertEqual(config.seed, day.seed)
    }

    func testTheBattleIsFifteenQuestionsWithAFourSecondTimer() throws {
        let day = challenge(2026, 1, 1, chapter: 2)
        guard case .battle(let config)? = day.playKind else { return XCTFail("expected a battle") }
        XCTAssertEqual(config.questionCount, 15)
        XCTAssertEqual(config.timePerNote, 4)
        XCTAssertEqual(config.newPool, day.pool)
        XCTAssertEqual(config.seed, day.seed)
        XCTAssertFalse(config.isBoss)
    }

    func testTheSongSprintPerformsTheFirstThirtyTwoNotesAtNormalSpeed() throws {
        let day = challenge(2026, 1, 2, chapter: 6)
        guard case .song(let songId, let mode, let speed, let isBoss, let isSolemn, let noteLimit)? = day.playKind else {
            return XCTFail("expected a song")
        }
        XCTAssertEqual(songId, day.songId)
        XCTAssertEqual(mode, .perform)
        XCTAssertEqual(speed, 1)
        XCTAssertFalse(isBoss)
        XCTAssertFalse(isSolemn)
        XCTAssertEqual(noteLimit, 32)
    }

    func testOnlyTheSprintHasASong() {
        XCTAssertNil(challenge(2026, 1, 1).songId)
        XCTAssertNil(challenge(2026, 1, 3).songId)
        XCTAssertNotNil(challenge(2026, 1, 2).songId)
    }

    func testTheSprintSongFitsTheNotesTheChapterTaught() throws {
        for chapter in 1...6 {
            for day in stride(from: 2, through: 29, by: 3) {        // days whose type is the sprint
                let sprint = challenge(2026, 1, day, chapter: chapter)
                guard sprint.kind == .songSprint else { continue }
                let song = try XCTUnwrap(SongLibrary.song(id: try XCTUnwrap(sprint.songId)))
                XCTAssertFalse(song.isSolemn, "the anthem is never a sprint")
                let fitting = SongLibrary.all.filter { !$0.isSolemn && Set($0.keyIds.prefix(32)).isSubset(of: Set(sprint.pool)) }
                if !fitting.isEmpty {
                    XCTAssertTrue(Set(song.keyIds.prefix(32)).isSubset(of: Set(sprint.pool)), "chapter \(chapter): \(song.title)")
                }
            }
        }
    }

    func testTheSprintSongIsTheSameForEveryone() {
        XCTAssertEqual(challenge(2026, 1, 2, chapter: 3).songId, challenge(2026, 1, 2, chapter: 3).songId)
    }

    func testTheSprintSongVariesAcrossDays() {
        let songs = Set((0..<12).compactMap { challenge(2026, 1, 2 + 3 * $0, chapter: 6).songId })
        XCTAssertGreaterThan(songs.count, 3)
    }

    // MARK: Bad keys

    func testAKeyThatIsNotARealDateGivesNothing() {
        XCTAssertNil(DailyChallenge.make(dateKey: "20260230", chapter: 1, calendar: calendar), "no 30 February")
        XCTAssertNil(DailyChallenge.make(dateKey: "20261301", chapter: 1, calendar: calendar))
        XCTAssertNil(DailyChallenge.make(dateKey: "2026101", chapter: 1, calendar: calendar))
        XCTAssertNil(DailyChallenge.make(dateKey: "abcdefgh", chapter: 1, calendar: calendar))
        XCTAssertNotNil(DailyChallenge.make(dateKey: "20240229", chapter: 1, calendar: calendar), "2024 is a leap year")
    }

    func testBuildingFromAKeyMatchesBuildingFromTheDate() {
        let fromDate = challenge(2026, 10, 10, chapter: 2)
        let fromKey = DailyChallenge.make(dateKey: "20261010", chapter: 2, calendar: calendar)
        XCTAssertEqual(fromDate, fromKey)
    }
}

final class DailyRewardTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var recorder: ResultRecorder!

    override func setUp() {
        super.setUp()
        suiteName = "DailyRewardTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func daily(_ dateKey: String, won: Bool = true, kind: PlayRequest.Kind? = nil) -> PlayResult {
        let config = BattleConfig(newPool: [5, 6, 7], questionCount: 15, timePerNote: 4, seed: 1)
        let request = PlayRequest(kind: kind ?? .battle(config), dailyDateKey: dateKey)
        return PlayResult(request: request, didWin: won, stars: won ? 3 : 0, score: 150, accuracy: 100, maxCombo: 15,
                          perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
    }

    func testWinningPaysTheBaseRewardPlusTheStreakBonus() {
        // A first play today makes the streak 1, so the reward is 50 + 10.
        let rewards = recorder.record(daily("20261010"))
        XCTAssertEqual(progress.currentStreak, 1)
        XCTAssertEqual(rewards.coins, 60)
        XCTAssertEqual(progress.coinBalance, 60)
        XCTAssertTrue(progress.isDailyDone("20261010"))
    }

    func testTheRewardIsPaidOnlyOncePerDate() {
        recorder.record(daily("20261010"))
        let again = recorder.record(daily("20261010"))
        XCTAssertEqual(again.coins, 0)
        XCTAssertEqual(progress.coinBalance, 60)
    }

    func testALostChallengePaysNothingAndCanBeTriedAgain() {
        XCTAssertEqual(recorder.record(daily("20261010", won: false)).coins, 0)
        XCTAssertFalse(progress.isDailyDone("20261010"))
        XCTAssertEqual(recorder.record(daily("20261010")).coins, 60, "the next try can still win it")
    }

    func testEachDateHasItsOwnReward() {
        recorder.record(daily("20261010"))
        XCTAssertFalse(progress.isDailyDone("20261011"))
        XCTAssertGreaterThan(recorder.record(daily("20261011")).coins, 0)
        XCTAssertTrue(progress.isDailyDone("20261010"))
        XCTAssertTrue(progress.isDailyDone("20261011"))
    }

    func testADailyPlayCountsTowardsTheStreak() {
        XCTAssertEqual(progress.currentStreak, 0)
        recorder.record(daily("20261010", won: false))
        XCTAssertEqual(progress.currentStreak, 1, "playing counts even when you lose")
    }

    func testTheBonusStopsGrowingAtFiveStreakDays() {
        XCTAssertEqual(CoinRewards.daily(streak: 5), 100)
        XCTAssertEqual(CoinRewards.daily(streak: 9), 100)
    }

    func testADailySprintDoesNotTouchTheSongsOwnRecords() {
        let songId = SongLibrary.slug(for: "Terima Kasih Guru")
        let kind = PlayRequest.Kind.song(songId: songId, mode: .perform, speed: 1, isBoss: false, isSolemn: false, noteLimit: 32)
        let result = PlayResult(request: PlayRequest(kind: kind, dailyDateKey: "20261010"), didWin: true, stars: 3, score: 9_000,
                                accuracy: 98, maxCombo: 32, perfect: 30, great: 2, good: 0, miss: 0, wrong: 0)
        let rewards = recorder.record(result)
        XCTAssertEqual(rewards.coins, 60, "only the daily reward, not the 30 for three new stars")
        XCTAssertEqual(progress.songStars(songId), 0)
        XCTAssertEqual(progress.songBestScore(songId), 0)
        XCTAssertEqual(progress.statSongsPerformed, 0)
        XCTAssertFalse(progress.isSongFullCombo(songId))
    }

    func testTheDailyFlagUsesTheDocumentedKey() {
        recorder.record(daily("20261010"))
        XCTAssertTrue(defaults.bool(forKey: "daily_done_20261010"))
    }

    // MARK: Streak projection

    private func day(_ offset: Int, from base: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: base)!
    }

    func testTheStreakProjectionForANewPlayerIsOne() {
        XCTAssertEqual(progress.streakAfterPlayingToday(), 1)
    }

    func testTheProjectionContinuesAStreakFromYesterdayButNotFromEarlier() {
        let today = Date()
        progress.registerPlayToday(now: day(-1, from: today))
        XCTAssertEqual(progress.currentStreak, 1)
        XCTAssertEqual(progress.streakAfterPlayingToday(now: today), 2)

        let later = day(2, from: today)
        XCTAssertEqual(progress.streakAfterPlayingToday(now: later), 1, "a gap resets it")
    }

    func testTheProjectionIsUnchangedOnceYouHavePlayedToday() {
        let today = Date()
        progress.registerPlayToday(now: day(-1, from: today))
        progress.registerPlayToday(now: today)
        XCTAssertEqual(progress.currentStreak, 2)
        XCTAssertEqual(progress.streakAfterPlayingToday(now: today), 2)
    }
}
