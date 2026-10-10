import XCTest
@testable import Melodissimo

final class AchievementTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var store: AchievementStore!

    override func setUp() {
        super.setUp()
        suiteName = "AchievementTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        store = AchievementStore(defaults: defaults, progress: progress)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func isEarned(_ id: String) -> Bool {
        store.achievements.first { $0.id == id }?.isEarned ?? false
    }

    // MARK: Catalog

    func testTheCatalogHasTheSevenOldAndTheSevenNewBadges() {
        let ids = store.achievements.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "ids are unique")
        XCTAssertEqual(ids.count, 14)
        for id in ["first_show", "full_combo", "golden_ear", "fals_hunter", "sabang_merauke", "rush_100", "collector"] {
            XCTAssertTrue(ids.contains(id), id)
        }
    }

    func testTheNewBadgesCarryTheTitlesFromThePlan() {
        // The titles are English keys; the Indonesian ones from the plan are in id.lproj (see LocalizationTests).
        let titles = Dictionary(uniqueKeysWithValues: store.achievements.map { ($0.id, $0.title) })
        XCTAssertEqual(titles["first_show"], "First Show")
        XCTAssertEqual(titles["full_combo"], "Flawless")
        XCTAssertEqual(titles["golden_ear"], "Golden Ear")
        XCTAssertEqual(titles["fals_hunter"], "Fals Hunter")
        XCTAssertEqual(titles["sabang_merauke"], "From Sabang to Merauke")
        XCTAssertEqual(titles["rush_100"], "Lightning")
        XCTAssertEqual(titles["collector"], "Collector")
    }

    func testEveryBadgeHasADetailAndASymbol() {
        for achievement in store.achievements {
            XCTAssertFalse(achievement.detail.isEmpty, achievement.id)
            XCTAssertNotNil(UIImage(systemName: achievement.systemImage), "\(achievement.id): \(achievement.systemImage)")
        }
    }

    func testNothingIsEarnedOnAFreshProfile() {
        XCTAssertTrue(store.evaluate().isEmpty)
        XCTAssertTrue(store.achievements.allSatisfy { !$0.isEarned })
    }

    // MARK: Conditions

    func testPanggungPertamaComesWithTheFirstPerform() {
        store.evaluate()
        XCTAssertFalse(isEarned("first_show"))
        progress.incrementSongsPerformed()
        XCTAssertEqual(store.evaluate().map(\.id), ["first_show"])
        XCTAssertTrue(isEarned("first_show"))
    }

    func testTanpaCelaComesWithTheFirstFullCombo() {
        progress.incrementSongsPerformed()
        store.evaluate()
        XCTAssertFalse(isEarned("full_combo"))
        progress.incrementFullCombos()
        XCTAssertTrue(store.evaluate().map(\.id).contains("full_combo"))
    }

    func testTelingaEmasNeedsTenEchoRounds() {
        progress.recordEchoBestRounds(9)
        store.evaluate()
        XCTAssertFalse(isEarned("golden_ear"))
        progress.recordEchoBestRounds(10)
        store.evaluate()
        XCTAssertTrue(isEarned("golden_ear"))
    }

    func testPemburuFalsNeedsThreeBosses() {
        progress.incrementBossesDefeated()
        progress.incrementBossesDefeated()
        store.evaluate()
        XCTAssertFalse(isEarned("fals_hunter"))
        progress.incrementBossesDefeated()
        store.evaluate()
        XCTAssertTrue(isEarned("fals_hunter"))
    }

    func testDariSabangSampaiMeraukeComesWithTheFinale() {
        store.evaluate()
        XCTAssertFalse(isEarned("sabang_merauke"))
        progress.recordTourCompleted()
        store.evaluate()
        XCTAssertTrue(isEarned("sabang_merauke"))
    }

    func testKilatNeedsARushScoreOfAHundred() {
        progress.recordRushScore(99)
        store.evaluate()
        XCTAssertFalse(isEarned("rush_100"))
        progress.recordRushScore(100)
        store.evaluate()
        XCTAssertTrue(isEarned("rush_100"))
    }

    func testKolektorNeedsThreeBoughtItems() {
        progress.earn(1_000)
        XCTAssertTrue(progress.buy(ShopCatalog.item(id: "keyboard_batik")!))
        XCTAssertTrue(progress.buy(ShopCatalog.item(id: "notes_rainbow")!))
        store.evaluate()
        XCTAssertFalse(isEarned("collector"), "free defaults don't count")
        XCTAssertTrue(progress.buy(ShopCatalog.item(id: "outfit_glasses")!))
        XCTAssertEqual(store.evaluate().map(\.id), ["collector"])
    }

    // MARK: Evaluation

    func testABadgeIsReportedOnceAndStaysEarned() {
        progress.recordRushScore(150)
        XCTAssertEqual(store.evaluate().map(\.id), ["rush_100"])
        XCTAssertTrue(store.evaluate().isEmpty, "already earned")
        XCTAssertTrue(AchievementStore(defaults: defaults, progress: progress).achievements.first { $0.id == "rush_100" }!.isEarned,
                      "it is stored, not recomputed")
    }

    func testAPerfectPerformThroughTheRecorderUnlocksTheFirstTwoBadges() {
        let recorder = ResultRecorder(progress: progress, evaluateAchievements: { [store] in store!.evaluate().map(\.title) })
        let request = PlayRequest(kind: .song(songId: "berkibarlah-benderaku", mode: .perform, speed: 1,
                                              isBoss: false, isSolemn: false, noteLimit: nil))
        let result = PlayResult(request: request, didWin: true, stars: 3, score: 9_000, accuracy: 99, maxCombo: 30,
                                perfect: 30, great: 0, good: 0, miss: 0, wrong: 0)
        let summary = recorder.record(result)
        XCTAssertTrue(summary.newAchievements.contains("First Show"))
        XCTAssertTrue(summary.newAchievements.contains("Flawless"))
    }

    func testResettingProgressLetsTheBadgesBeEarnedAgain() {
        progress.recordRushScore(200)
        store.evaluate()
        XCTAssertTrue(isEarned("rush_100"))
        progress.resetProgress()
        store.reload()
        XCTAssertFalse(isEarned("rush_100"))
    }
}
