import XCTest
@testable import Melodissimo

final class MapLayoutTests: XCTestCase {

    func testOneNodePerStageSpreadLeftToRight() {
        for count in [6, 7, 9, 11] {
            let points = MapLayout.nodeFractions(count: count)
            XCTAssertEqual(points.count, count)
            XCTAssertEqual(points.first?.x ?? 0, MapLayout.leftMargin, accuracy: 1e-9)
            XCTAssertEqual(points.last?.x ?? 0, MapLayout.rightMargin, accuracy: 1e-9)
            XCTAssertTrue(zip(points, points.dropFirst()).allSatisfy { $0.x < $1.x }, "x strictly increases")
        }
    }

    func testTheNodesZigZagBetweenTwoRows() {
        let points = MapLayout.nodeFractions(count: 7)
        XCTAssertEqual(points.map(\.y), [0.70, 0.50, 0.70, 0.50, 0.70, 0.50, 0.70])
    }

    func testEverythingStaysInsideThePanelAndBelowTheHeader() {
        for point in MapLayout.nodeFractions(count: 11) {
            XCTAssertGreaterThan(point.x, 0)
            XCTAssertLessThan(point.x, 1)
            XCTAssertGreaterThanOrEqual(point.y, 0.4, "the top of the panel is for the island name")
            XCTAssertLessThan(point.y, 1)
        }
    }

    func testEdgeCases() {
        XCTAssertTrue(MapLayout.nodeFractions(count: 0).isEmpty)
        XCTAssertEqual(MapLayout.nodeFractions(count: 1), [CGPoint(x: 0.5, y: MapLayout.lowerRow)])
    }

    func testPointsScaleToThePanel() {
        let points = MapLayout.points(count: 2, in: CGSize(width: 1000, height: 500))
        XCTAssertEqual(points[0].x, 80, accuracy: 1e-9)
        XCTAssertEqual(points[0].y, 350, accuracy: 1e-9)
        XCTAssertEqual(points[1].x, 920, accuracy: 1e-9)
        XCTAssertEqual(points[1].y, 250, accuracy: 1e-9)
    }

    func testEveryChapterHasEnoughRoomForItsNodes() {
        // The widest chapters have 11 stages; neighbours must stay at least 8 % of the panel apart horizontally.
        for chapter in CampaignCatalog.chapters {
            let count = CampaignCatalog.stages(inChapter: chapter.number).count
            let points = MapLayout.nodeFractions(count: count)
            let gaps = zip(points, points.dropFirst()).map { $1.x - $0.x }
            XCTAssertGreaterThanOrEqual(gaps.min() ?? 1, 0.08, "chapter \(chapter.number)")
        }
    }
}

final class CampaignStageRecordingTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private var recorder: ResultRecorder!

    override func setUp() {
        super.setUp()
        suiteName = "CampaignStageRecordingTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
        recorder = ResultRecorder(progress: progress, evaluateAchievements: { [] })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func battle(stage: String?, won: Bool, hearts: Int) -> PlayResult {
        let config = BattleConfig(newPool: [5, 6, 7], questionCount: 6, timePerNote: nil, seed: 1)
        return PlayResult(request: PlayRequest(kind: .battle(config), campaignStageId: stage), didWin: won,
                          stars: won ? hearts : 0, score: 60, accuracy: 100, maxCombo: 6,
                          perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
    }

    func testAWonBattleRecordsItsStageStarsAndTheGain() {
        let summary = recorder.record(battle(stage: "c1-01", won: true, hearts: 2))
        XCTAssertEqual(progress.stageStars("c1-01"), 2)
        XCTAssertEqual(summary.newStars, 2)
        XCTAssertEqual(defaults.integer(forKey: "stage_stars_c1-01"), 2)
    }

    func testOnlyABetterRunAddsStars() {
        recorder.record(battle(stage: "c1-01", won: true, hearts: 2))
        let worse = recorder.record(battle(stage: "c1-01", won: true, hearts: 1))
        XCTAssertEqual(progress.stageStars("c1-01"), 2)
        XCTAssertEqual(worse.newStars, 0)
        let better = recorder.record(battle(stage: "c1-01", won: true, hearts: 3))
        XCTAssertEqual(progress.stageStars("c1-01"), 3)
        XCTAssertEqual(better.newStars, 1)
    }

    func testALostBattleEarnsNothingAndUnlocksNothing() {
        recorder.record(battle(stage: "c1-01", won: false, hearts: 0))
        XCTAssertEqual(progress.stageStars("c1-01"), 0)
        XCTAssertFalse(progress.isUnlocked(CampaignCatalog.stage(id: "c1-02")!))
    }

    func testWinningAStageOpensTheNextOne() {
        XCTAssertFalse(progress.isUnlocked(CampaignCatalog.stage(id: "c1-02")!))
        recorder.record(battle(stage: "c1-01", won: true, hearts: 1))
        XCTAssertTrue(progress.isUnlocked(CampaignCatalog.stage(id: "c1-02")!))
        XCTAssertEqual(progress.currentStage.id, "c1-02")
    }

    func testPlaysOutsideTheCampaignNeverTouchStageStars() {
        recorder.record(battle(stage: nil, won: true, hearts: 3))
        XCTAssertEqual(progress.tourStars, 0)
    }

    func testAnEchoStageRecordsStarsToo() {
        let config = EchoConfig(pool: [5, 6, 7], roundsToClear: 3, seed: 1)
        let result = PlayResult(request: PlayRequest(kind: .echo(config), campaignStageId: "c1-03"), didWin: true, stars: 3,
                                score: 3, accuracy: nil, maxCombo: 0, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        let summary = recorder.record(result)
        XCTAssertEqual(progress.stageStars("c1-03"), 3)
        XCTAssertEqual(summary.newStars, 3)
    }

    func testASongStageRecordsItsPerformStarsAndKeepsTheSongsOwnGain() {
        let request = PlayRequest(kind: .song(songId: "berkibarlah-benderaku", mode: .perform, speed: 1, isBoss: false,
                                              isSolemn: false, noteLimit: nil), campaignStageId: "c1-04")
        let result = PlayResult(request: request, didWin: true, stars: 2, score: 9000, accuracy: 88, maxCombo: 30,
                                perfect: 60, great: 10, good: 2, miss: 2, wrong: 1)
        let summary = recorder.record(result)
        XCTAssertEqual(progress.stageStars("c1-04"), 2)
        XCTAssertEqual(progress.songStars("berkibarlah-benderaku"), 2)
        XCTAssertEqual(summary.newStars, 2, "the song's own gain")
    }

    func testPracticingACampaignSongDoesNotAwardStageStars() {
        let request = PlayRequest(kind: .song(songId: "berkibarlah-benderaku", mode: .practice, speed: 1, isBoss: false,
                                              isSolemn: false, noteLimit: nil), campaignStageId: "c1-04")
        let result = PlayResult(request: request, didWin: true, stars: 0, score: 0, accuracy: nil, maxCombo: 0,
                                perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        recorder.record(result)
        XCTAssertEqual(progress.stageStars("c1-04"), 0)
    }
}
