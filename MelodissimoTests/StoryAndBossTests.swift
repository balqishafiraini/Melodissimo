import XCTest
@testable import Melodissimo

final class BossHealthTests: XCTestCase {

    private func counts(perfect: Int = 0, great: Int = 0, good: Int = 0, miss: Int = 0) -> JudgmentCounts {
        JudgmentCounts(perfect: perfect, great: great, good: good, miss: miss)
    }

    func testAFreshBossIsAtFullHealth() {
        XCTAssertEqual(BossHealth.fraction(counts: counts(), totalNotes: 40), 1, accuracy: 1e-9)
    }

    func testEveryPerfectTakesAnEqualShare() {
        XCTAssertEqual(BossHealth.fraction(counts: counts(perfect: 10), totalNotes: 40), 0.75, accuracy: 1e-9)
        XCTAssertEqual(BossHealth.fraction(counts: counts(perfect: 40), totalNotes: 40), 0, accuracy: 1e-9)
    }

    func testGreatAndGoodHurtLessThanPerfect() {
        XCTAssertEqual(BossHealth.fraction(counts: counts(great: 10), totalNotes: 40), 1 - 0.1875, accuracy: 1e-9)
        XCTAssertEqual(BossHealth.fraction(counts: counts(good: 10), totalNotes: 40), 1 - 0.1, accuracy: 1e-9)
    }

    func testMissesNeverHealIt() {
        let before = BossHealth.fraction(counts: counts(perfect: 10), totalNotes: 40)
        let after = BossHealth.fraction(counts: counts(perfect: 10, miss: 30), totalNotes: 40)
        XCTAssertEqual(before, after, accuracy: 1e-9)
    }

    func testHealthStaysInsideZeroToOne() {
        XCTAssertEqual(BossHealth.fraction(counts: counts(perfect: 100), totalNotes: 40), 0, accuracy: 1e-9)
        XCTAssertEqual(BossHealth.fraction(counts: counts(perfect: 5), totalNotes: 0), 1, accuracy: 1e-9)
    }

    func testTheDefeatLineIsTheFirstStar() {
        // 60 % of the notes hit perfectly leaves the boss on the defeat line, and that is exactly 1★.
        let health = BossHealth.fraction(counts: counts(perfect: 60), totalNotes: 100)
        XCTAssertEqual(health, BossHealth.defeatFraction, accuracy: 1e-9)
        XCTAssertEqual(Judge.stars(forAccuracy: 60), 1)
        XCTAssertEqual(Judge.stars(forAccuracy: 59.9), 0)
    }
}

final class StoryCardTests: XCTestCase {

    func testThereAreThirteenCardsWithUniqueIds() {
        XCTAssertEqual(StoryCatalog.cards.count, 13)
        XCTAssertEqual(Set(StoryCatalog.cards.map(\.id)).count, 13)
    }

    func testEveryChapterHasAnIntroAndABossCard() {
        for chapter in 1...6 {
            XCTAssertEqual(StoryCatalog.cards.filter { $0.chapter == chapter && $0.kind == .chapterIntro }.count, 1, "intro \(chapter)")
            XCTAssertEqual(StoryCatalog.cards.filter { $0.chapter == chapter && $0.kind == .bossDefeated }.count, 1, "boss \(chapter)")
        }
        XCTAssertEqual(StoryCatalog.cards.filter { $0.kind == .finale }.count, 1)
    }

    func testEveryCardHasTwoOrThreeShortLines() {
        for card in StoryCatalog.cards {
            XCTAssertTrue((2...3).contains(card.lines.count), card.id)
            for line in card.lines {
                XCTAssertLessThanOrEqual(line.count, 70, "\(card.id): \(line)")
            }
        }
    }

    /// Looks a string up in the Indonesian table of the app bundle.
    private func indonesian(_ key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "id"),
              let table = NSDictionary(contentsOfFile: path) as? [String: String] else { return nil }
        return table[key]
    }

    func testEveryLineIsTranslatedIntoIndonesian() {
        for card in StoryCatalog.cards {
            for line in card.lines {
                let translation = indonesian(line)
                XCTAssertNotNil(translation, "\(card.id): missing Indonesian for \"\(line)\"")
                XCTAssertNotEqual(translation, line, "\(card.id): the Indonesian line is still English")
            }
        }
    }

    // MARK: pending()

    private func pending(chapter: Int, stars: [String: Int] = [:], seen: Set<String> = []) -> [String] {
        StoryCatalog.pending(currentChapter: chapter, stars: { stars[$0] ?? 0 }, seen: { seen.contains($0) }).map(\.id)
    }

    private func bossId(_ chapter: Int) -> String {
        StoryCatalog.bossStage(inChapter: chapter)!.id
    }

    func testANewPlayerSeesTheFirstIntro() {
        XCTAssertEqual(pending(chapter: 1), ["intro_1"])
    }

    func testASeenCardIsNotShownAgain() {
        XCTAssertEqual(pending(chapter: 1, seen: ["intro_1"]), [])
    }

    func testBeatingABossShowsItsCardThenTheNextIntro() {
        let beaten = [bossId(1): 1]
        XCTAssertEqual(pending(chapter: 2, stars: beaten, seen: ["intro_1"]), ["boss_1", "intro_2"])
    }

    func testAPlayerWhoStartsFurtherAlongOnlySeesTheirOwnIntro() {
        XCTAssertEqual(pending(chapter: 4), ["intro_4"])
    }

    func testABossWithoutAStarShowsNoCard() {
        XCTAssertEqual(pending(chapter: 1, stars: [bossId(1): 0], seen: ["intro_1"]), [])
    }

    func testTheLastBossShowsItsCardThenTheFinaleCard() {
        let beaten = [bossId(6): 2]
        XCTAssertEqual(pending(chapter: 6, stars: beaten, seen: ["intro_6"]), ["boss_6", "finale"])
    }

    func testTheCertificateWaitsForAStarOnTheFinale() {
        let finale = StoryCatalog.finaleStage()!
        XCTAssertEqual(finale.chapter, 6)
        XCTAssertFalse(StoryCatalog.shouldShowCertificate(stars: { _ in 0 }, seen: { _ in false }))
        XCTAssertTrue(StoryCatalog.shouldShowCertificate(stars: { $0 == finale.id ? 1 : 0 }, seen: { _ in false }))
        XCTAssertFalse(StoryCatalog.shouldShowCertificate(stars: { $0 == finale.id ? 3 : 0 },
                                                          seen: { $0 == StoryCatalog.certificateId }))
    }
}

final class BossRecordingTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var recorder: ResultRecorder!

    override func setUp() {
        super.setUp()
        suiteName = "BossRecordingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private var firstBoss: String { StoryCatalog.bossStage(inChapter: 1)!.id }
    private var secondBoss: String { StoryCatalog.bossStage(inChapter: 2)!.id }

    private func perform(stars: Int, boss: Bool = true, stage: String? = nil, mode: StageMode = .perform) -> PlayResult {
        let kind = PlayRequest.Kind.song(songId: SongLibrary.slug(for: "Terima Kasih Guru"), mode: mode, speed: 1,
                                         isBoss: boss, isSolemn: false, noteLimit: nil)
        return PlayResult(request: PlayRequest(kind: kind, campaignStageId: stage ?? firstBoss), didWin: stars > 0, stars: stars,
                          score: 1000, accuracy: 70, maxCombo: 8, perfect: 5, great: 3, good: 2, miss: 1, wrong: 0)
    }

    func testTheFirstDefeatCountsAsABossDefeated() {
        recorder.record(perform(stars: 1))
        XCTAssertEqual(progress.statBossesDefeated, 1)
        XCTAssertEqual(progress.stageStars(firstBoss), 1)
    }

    func testBeatingTheSameBossAgainDoesNotCountTwice() {
        recorder.record(perform(stars: 1))
        recorder.record(perform(stars: 3))
        XCTAssertEqual(progress.statBossesDefeated, 1)
        XCTAssertEqual(progress.stageStars(firstBoss), 3)
    }

    func testALostBossFightDoesNotCount() {
        recorder.record(perform(stars: 0))
        XCTAssertEqual(progress.statBossesDefeated, 0)
        XCTAssertEqual(progress.stageStars(firstBoss), 0)
    }

    func testPracticeDoesNotDefeatABoss() {
        recorder.record(perform(stars: 0, mode: .practice))
        XCTAssertEqual(progress.statBossesDefeated, 0)
    }

    func testOrdinarySongStagesAreNotBosses() {
        recorder.record(perform(stars: 2, boss: false, stage: "c1-04"))
        XCTAssertEqual(progress.statBossesDefeated, 0)
    }

    func testTheFinalesFirstStarCompletesTheTourOnce() throws {
        let finale = try XCTUnwrap(StoryCatalog.finaleStage())
        XCTAssertNil(progress.tourCompletedAt)

        recorder.record(perform(stars: 0, boss: false, stage: finale.id))
        XCTAssertNil(progress.tourCompletedAt, "no star, no certificate")

        recorder.record(perform(stars: 1, boss: false, stage: finale.id))
        let first = try XCTUnwrap(progress.tourCompletedAt)

        progress.recordTourCompleted(on: first.addingTimeInterval(86_400))
        XCTAssertEqual(progress.tourCompletedAt, first, "only the first completion counts")
    }

    func testOnlyTheFinaleCompletesTheTour() {
        recorder.record(perform(stars: 3, boss: true, stage: firstBoss))
        XCTAssertNil(progress.tourCompletedAt)
    }

    func testTwoDifferentBossesCountSeparately() {
        recorder.record(perform(stars: 1, stage: firstBoss))
        recorder.record(perform(stars: 2, stage: secondBoss))
        XCTAssertEqual(progress.statBossesDefeated, 2)
    }
}

final class StorySeenTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "StorySeenTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testMarkingACardSeenIsRemembered() {
        XCTAssertFalse(progress.isStorySeen("intro_1"))
        progress.markStorySeen("intro_1")
        XCTAssertTrue(progress.isStorySeen("intro_1"))
        XCTAssertTrue(defaults.bool(forKey: "story_seen_intro_1"))
    }

    func testAFreshProfileHasTheFirstIntroPending() {
        progress.runMigrationIfNeeded()
        XCTAssertEqual(progress.pendingStoryCards.map(\.id), ["intro_1"])
        progress.markStorySeen("intro_1")
        XCTAssertTrue(progress.pendingStoryCards.isEmpty)
    }

    func testClearingTheFirstBossQueuesItsCardAndTheNextIntro() {
        progress.runMigrationIfNeeded()
        progress.markStorySeen("intro_1")
        for stage in CampaignCatalog.stages(inChapter: 1) {
            progress.recordStageStars(stage.id, stars: 1)
        }
        XCTAssertEqual(progress.pendingStoryCards.map(\.id), ["boss_1", "intro_2"])
    }

    func testTheCertificateIsPendingOnlyOnce() {
        let finale = StoryCatalog.finaleStage()!
        XCTAssertFalse(progress.isCertificatePending)
        progress.recordStageStars(finale.id, stars: 1)
        XCTAssertTrue(progress.isCertificatePending)
        progress.markStorySeen(StoryCatalog.certificateId)
        XCTAssertFalse(progress.isCertificatePending)
    }
}
