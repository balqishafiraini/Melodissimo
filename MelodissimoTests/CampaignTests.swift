import XCTest
@testable import Melodissimo

final class CampaignTests: XCTestCase {

    private let stages = CampaignCatalog.allStages

    private func songNotes(_ songId: String) -> Set<Int> {
        Set(SongLibrary.song(id: songId)!.keyIds)
    }

    // MARK: Catalog shape

    func testThereAreFiftyThreeStagesWithUniqueIds() {
        XCTAssertEqual(stages.count, 53)
        XCTAssertEqual(Set(stages.map(\.id)).count, 53)
        XCTAssertEqual(CampaignCatalog.chapters.map { CampaignCatalog.stages(inChapter: $0.number).count }, [7, 11, 9, 11, 9, 6])
    }

    func testStageIdsAreChapterAndTwoDigitIndex() {
        XCTAssertEqual(stages.first?.id, "c1-01")
        XCTAssertEqual(stages.last?.id, "c6-06")
        XCTAssertNotNil(CampaignCatalog.stage(id: "c2-05"))
        XCTAssertNil(CampaignCatalog.stage(id: "c9-01"))
        for stage in stages {
            XCTAssertEqual(stage.id, String(format: "c%d-%02d", stage.chapter, stage.index))
        }
        for chapter in CampaignCatalog.chapters {
            let indices = CampaignCatalog.stages(inChapter: chapter.number).map(\.index)
            XCTAssertEqual(indices, Array(1...indices.count))
        }
    }

    func testEveryChapterFollowsTheGenerationRule() {
        for chapter in CampaignCatalog.chapters {
            let kinds = CampaignCatalog.stages(inChapter: chapter.number).map(\.kind)
            guard case .battle(let b1) = kinds[0], case .battle(let b2) = kinds[1], case .echo(let e1) = kinds[2] else {
                return XCTFail("chapter \(chapter.number) must open with battle, battle, echo")
            }
            XCTAssertEqual(b1.questionCount, 6)
            XCTAssertNil(b1.timePerNote)
            XCTAssertEqual(b1.newPool, Array(chapter.newNotes.prefix(3)))
            XCTAssertEqual(b2.questionCount, 8)
            XCTAssertEqual(b2.timePerNote, chapter.timer)
            XCTAssertEqual(e1.roundsToClear, 3)
            XCTAssertEqual(e1.startLength, 2)
            XCTAssertTrue(e1.glowDuringPlayback)

            // song, battle pairs
            var cursor = 3
            for title in chapter.songTitles {
                XCTAssertEqual(kinds[cursor], .song(songId: SongLibrary.slug(for: title)))
                guard case .battle(let config) = kinds[cursor + 1] else { return XCTFail("a battle follows each song") }
                XCTAssertEqual(config.questionCount, 10)
                XCTAssertEqual(config.timePerNote, chapter.timer)
                XCTAssertEqual(config.newPool, chapter.newNotes)
                cursor += 2
            }

            guard case .echo(let e2) = kinds[cursor] else { return XCTFail("a second echo comes before the boss") }
            XCTAssertEqual(e2.roundsToClear, 5)
            XCTAssertEqual(e2.startLength, 3)
            XCTAssertFalse(e2.glowDuringPlayback)
            XCTAssertEqual(kinds[cursor + 1], .boss(songId: SongLibrary.slug(for: chapter.bossSongTitle)))
            if let finale = chapter.finaleSongTitle {
                XCTAssertEqual(kinds[cursor + 2], .finale(songId: SongLibrary.slug(for: finale)))
                XCTAssertEqual(kinds.count, cursor + 3)
            } else {
                XCTAssertEqual(kinds.count, cursor + 2)
            }
        }
    }

    func testFirstChapterHasNoReviewAndUsesAPrefixOfTheNewNotes() {
        let chapter1 = CampaignCatalog.stages(inChapter: 1)
        guard case .battle(let b2) = chapter1[1].kind else { return XCTFail() }
        XCTAssertEqual(b2.newPool, [5, 6, 7, 8, 9])
        XCTAssertTrue(b2.reviewPool.isEmpty)
        XCTAssertNil(b2.timePerNote, "chapter 1 has no timer")
    }

    func testLaterChaptersMixInReviewFromEarlierChapters() {
        let chapter3 = CampaignCatalog.stages(inChapter: 3)
        guard case .battle(let b2) = chapter3[1].kind else { return XCTFail() }
        XCTAssertEqual(b2.newPool, [1, 13, 14])
        XCTAssertEqual(Set(b2.reviewPool), Set(CampaignCatalog.notesTaught(through: 2)))
        XCTAssertEqual(b2.newWeight, 0.7)
        XCTAssertEqual(b2.timePerNote, 5)
    }

    func testChapterTimersFollowThePlan() {
        XCTAssertEqual(CampaignCatalog.chapters.map(\.timer), [nil, 6, 5, 4.5, 4, 3.5])
    }

    func testEchoPoolsAddOnlyNearbyReviewNotes() {
        let chapter2 = CampaignCatalog.stages(inChapter: 2)
        guard case .echo(let e1) = chapter2[2].kind else { return XCTFail() }
        // New notes 7. 6. 5. (ids 4, 3, 2) plus at most five review notes.
        XCTAssertTrue(Set([4, 3, 2]).isSubset(of: Set(e1.pool)))
        XCTAssertLessThanOrEqual(e1.pool.count, 3 + 5)
        // The review notes are the ones closest in pitch: the bottom of the old range (ids 5, 6, 7, 8, 9).
        XCTAssertEqual(Set(e1.pool), Set([4, 3, 2, 5, 6, 7, 8, 9]))
        guard case .echo(let e2) = chapter2[chapter2.count - 2].kind else { return XCTFail() }
        XCTAssertEqual(Set(e2.pool), Set([4, 3, 2] + [5, 6, 7, 8, 9, 10, 11, 12]))
        XCTAssertEqual(e2.pool.count, 11)
    }

    func testNearestReviewNotesOrdersByPitchDistanceThenId() {
        // F3 = 0, G3 = 2 … key 1 is at semitone 0, key 5 at 7, key 12 at 19.
        XCTAssertEqual(CampaignCatalog.nearestReviewNotes([12, 5, 8], to: [1], limit: 2), [5, 8])
        XCTAssertEqual(CampaignCatalog.nearestReviewNotes([], to: [1], limit: 5), [])
        XCTAssertEqual(CampaignCatalog.nearestReviewNotes([5, 6], to: [], limit: 5), [5, 6], "no new notes: keep id order")
    }

    func testSeedsAreDerivedFromTheStageIdAndStableBetweenCalls() {
        let again = CampaignCatalog.stages(inChapter: 2)
        let first = CampaignCatalog.stages(inChapter: 2)
        XCTAssertEqual(again, first)
        for stage in stages {
            switch stage.kind {
            case .battle(let config): XCTAssertEqual(config.seed, SeededRandom.seed(from: stage.id))
            case .echo(let config): XCTAssertEqual(config.seed, SeededRandom.seed(from: stage.id))
            default: break
            }
        }
        let seeds = stages.compactMap { stage -> UInt64? in
            if case .battle(let config) = stage.kind { return config.seed }
            if case .echo(let config) = stage.kind { return config.seed }
            return nil
        }
        XCTAssertEqual(Set(seeds).count, seeds.count)
    }

    // MARK: Curriculum

    func testEverySongAppearsOnceAndTheListedNotesCoverTheKeyboard() {
        var used: [String] = []
        for chapter in CampaignCatalog.chapters {
            used += chapter.songTitles + [chapter.bossSongTitle] + (chapter.finaleSongTitle.map { [$0] } ?? [])
        }
        XCTAssertEqual(Set(used), Set(SongLibrary.all.map(\.title)))
        XCTAssertEqual(used.count, 18)
        XCTAssertEqual(Set(CampaignCatalog.notesTaught(through: 6)), Set(1...32))
        XCTAssertEqual(CampaignCatalog.chapters.flatMap(\.newNotes).count, 32, "no note is taught twice")
    }

    /// Proves the curriculum: no song stage asks for a note its chapter hasn't taught yet.
    func testEverySongBossAndFinaleOnlyUsesNotesTaughtSoFar() {
        for stage in stages {
            let taught = Set(CampaignCatalog.notesTaught(through: stage.chapter))
            switch stage.kind {
            case .song(let songId), .boss(let songId), .finale(let songId):
                XCTAssertTrue(songNotes(songId).isSubset(of: taught),
                              "\(stage.id) \(songId) uses \(songNotes(songId).subtracting(taught).sorted())")
            case .battle(let config):
                XCTAssertTrue(Set(config.newPool + config.reviewPool).isSubset(of: taught), stage.id)
            case .echo(let config):
                XCTAssertTrue(Set(config.pool).isSubset(of: taught), stage.id)
            }
        }
    }

    func testBattlesAlwaysTeachSomethingFromTheCurrentChapter() {
        for stage in stages {
            if case .battle(let config) = stage.kind {
                XCTAssertFalse(config.newPool.isEmpty, stage.id)
                XCTAssertTrue(Set(config.newPool).isSubset(of: Set(CampaignCatalog.chapter(stage.chapter).newNotes)), stage.id)
            }
        }
    }

    func testOnlyTheTwoSolemnSongsAreInSolemnPlaces() {
        // Mengheningkan Cipta is an ordinary song stage in chapter 5; Indonesia Raya is the finale.
        let finales = stages.compactMap { stage -> String? in
            if case .finale(let id) = stage.kind { return id }
            return nil
        }
        XCTAssertEqual(finales, ["indonesia-raya"])
        XCTAssertTrue(SongLibrary.song(id: "indonesia-raya")!.isSolemn)
        XCTAssertTrue(SongLibrary.song(id: "mengheningkan-cipta")!.isSolemn)
    }

    func testChapterSymbolsFollowThePlan() {
        XCTAssertEqual(CampaignCatalog.chapters.map(\.symbol),
                       ["leaf.fill", "building.columns.fill", "tree.fill", "sailboat.fill", "sun.max.fill", "mountain.2.fill"])
        XCTAssertEqual(CampaignCatalog.chapters.map(\.name),
                       ["Sumatra", "Jawa", "Kalimantan", "Sulawesi", "Bali & Nusa Tenggara", "Maluku & Papua"])
    }

    // MARK: Unlocking

    private func unlocked(_ stage: Stage, granted: Int = 1, stars: [String: Int] = [:]) -> Bool {
        CampaignCatalog.isUnlocked(stage, grantedChapter: granted) { stars[$0] ?? 0 }
    }

    func testOnlyTheFirstStageIsOpenAtTheStart() {
        let open = stages.filter { unlocked($0) }
        XCTAssertEqual(open.map(\.id), ["c1-01"])
    }

    func testAStarOpensTheNextStage() {
        let stars = ["c1-01": 1]
        XCTAssertTrue(unlocked(CampaignCatalog.stage(id: "c1-02")!, stars: stars))
        XCTAssertFalse(unlocked(CampaignCatalog.stage(id: "c1-03")!, stars: stars))
        XCTAssertFalse(unlocked(CampaignCatalog.stage(id: "c1-02")!, stars: ["c1-01": 0]))
    }

    func testClearingTheBossOpensTheNextChapter() {
        let lastOfChapter1 = CampaignCatalog.stages(inChapter: 1).last!
        let firstOfChapter2 = CampaignCatalog.stage(id: "c2-01")!
        XCTAssertFalse(unlocked(firstOfChapter2))
        XCTAssertFalse(unlocked(firstOfChapter2, stars: [lastOfChapter1.id: 0]))
        XCTAssertTrue(unlocked(firstOfChapter2, stars: [lastOfChapter1.id: 1]))
    }

    func testMigrationThresholds() {
        let expected = [(0, 1), (19, 1), (20, 2), (39, 2), (40, 3), (59, 3), (60, 4), (79, 4), (80, 5), (94, 5), (95, 6), (100, 6)]
        for (cleared, chapter) in expected {
            XCTAssertEqual(CampaignCatalog.grantedChapter(forClearedClassicLevels: cleared), chapter, "\(cleared) levels")
        }
    }

    func testAGrantedChapterOpensItsFirstStageOnly() {
        let chapter4Start = CampaignCatalog.stage(id: "c4-01")!
        XCTAssertTrue(unlocked(chapter4Start, granted: 4))
        XCTAssertTrue(unlocked(CampaignCatalog.stage(id: "c3-01")!, granted: 4), "earlier chapters stay reachable too")
        XCTAssertFalse(unlocked(CampaignCatalog.stage(id: "c4-02")!, granted: 4))
        XCTAssertFalse(unlocked(CampaignCatalog.stage(id: "c5-01")!, granted: 4))
        XCTAssertTrue(unlocked(CampaignCatalog.stage(id: "c4-02")!, granted: 4, stars: ["c4-01": 2]))
    }

    func testCurrentStageIsTheFirstOpenStageWithoutAStar() {
        func current(granted: Int = 1, _ stars: [String: Int] = [:]) -> String {
            CampaignCatalog.currentStage(grantedChapter: granted) { stars[$0] ?? 0 }.id
        }
        XCTAssertEqual(current(), "c1-01")
        XCTAssertEqual(current(["c1-01": 1]), "c1-02")
        XCTAssertEqual(current(["c1-01": 3, "c1-02": 1, "c1-03": 2]), "c1-04")
        XCTAssertEqual(current(granted: 3), "c3-01")
        XCTAssertEqual(current(granted: 3, ["c3-01": 1, "c3-02": 1]), "c3-03")
        XCTAssertEqual(current(granted: 0), "c1-01")
    }

    func testCurrentStageIsTheLastStageWhenTheTourIsDone() {
        let all = Dictionary(uniqueKeysWithValues: stages.map { ($0.id, 1) })
        XCTAssertEqual(CampaignCatalog.currentStage(grantedChapter: 1) { all[$0] ?? 0 }.id, "c6-06")
    }

    func testPreviousStageCrossesChapters() {
        XCTAssertNil(CampaignCatalog.previousStage(of: stages[0]))
        XCTAssertEqual(CampaignCatalog.previousStage(of: CampaignCatalog.stage(id: "c2-01")!)?.id, "c1-07")
        XCTAssertEqual(CampaignCatalog.previousStage(of: CampaignCatalog.stage(id: "c2-02")!)?.id, "c2-01")
    }
}

/// `ProgressStore` wrappers, against a throwaway `UserDefaults` suite.
final class CampaignProgressTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var store: ProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "CampaignProgressTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = ProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testStageStarsKeepTheBestAndAreClamped() {
        XCTAssertEqual(store.stageStars("c1-01"), 0)
        store.recordStageStars("c1-01", stars: 2)
        store.recordStageStars("c1-01", stars: 1)
        XCTAssertEqual(store.stageStars("c1-01"), 2)
        store.recordStageStars("c1-01", stars: 9)
        XCTAssertEqual(store.stageStars("c1-01"), 3)
        store.recordStageStars("c1-02", stars: -4)
        XCTAssertEqual(store.stageStars("c1-02"), 0)
        XCTAssertEqual(defaults.integer(forKey: "stage_stars_c1-01"), 3, "persisted under the documented key")
    }

    func testTotalsAndUnlocking() {
        store.recordStageStars("c1-01", stars: 3)
        store.recordStageStars("c1-02", stars: 1)
        XCTAssertEqual(store.chapterStars(1), 4)
        XCTAssertEqual(store.tourStars, 4)
        XCTAssertTrue(store.isUnlocked(CampaignCatalog.stage(id: "c1-03")!))
        XCTAssertFalse(store.isUnlocked(CampaignCatalog.stage(id: "c1-04")!))
        XCTAssertEqual(store.currentStage.id, "c1-03")
    }

    func testMigrationRunsOnceFromTheHighestClearedClassicLevel() {
        XCTAssertEqual(store.grantedChapter, 0)
        defaults.set(63, forKey: "currentLevel")
        store.runMigrationIfNeeded()
        XCTAssertEqual(store.grantedChapter, 4)
        XCTAssertTrue(store.isUnlocked(CampaignCatalog.stage(id: "c4-01")!))
        XCTAssertEqual(store.currentStage.id, "c4-01")

        defaults.set(99, forKey: "currentLevel")           // more progress later does not re-run it
        store.runMigrationIfNeeded()
        XCTAssertEqual(store.grantedChapter, 4)
        XCTAssertEqual(defaults.integer(forKey: "campaign_grantedChapter"), 4)
    }

    func testMigrationForANewPlayerGrantsChapterOne() {
        store.runMigrationIfNeeded()
        XCTAssertEqual(store.grantedChapter, 1)
        XCTAssertEqual(store.currentStage.id, "c1-01")
    }

    func testInjectedDefaultsDoNotTouchTheStandardStore() {
        store.recordStageStars("c1-01", stars: 3)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "stage_stars_c1-01"), 0)
    }
}
