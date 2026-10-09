import XCTest
@testable import Melodissimo

/// Song-stage progress, against a throwaway `UserDefaults` suite.
final class SongProgressTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var store: ProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "SongProgressTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = ProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testNothingIsRecordedForASongYouHaveNeverPlayed() {
        XCTAssertEqual(store.songBestScore("halo-halo-bandung"), 0)
        XCTAssertEqual(store.songBestAccuracy("halo-halo-bandung"), 0)
        XCTAssertEqual(store.songStars("halo-halo-bandung"), 0)
        XCTAssertFalse(store.isSongPracticed("halo-halo-bandung"))
        XCTAssertFalse(store.isSongFullCombo("halo-halo-bandung"))
    }

    func testPracticedFlagIsPerSongAndPersistedUnderTheDocumentedKey() {
        store.setSongPracticed("merah-putih")
        XCTAssertTrue(store.isSongPracticed("merah-putih"))
        XCTAssertFalse(store.isSongPracticed("ibu-pertiwi"))
        XCTAssertTrue(defaults.bool(forKey: "song_practiced_merah-putih"))
        store.setSongPracticed("merah-putih")        // idempotent
        XCTAssertTrue(store.isSongPracticed("merah-putih"))
    }

    func testReadsTheDocumentedKeys() {
        defaults.set(12_345, forKey: "song_bestScore_tanah-airku")
        defaults.set(87.5, forKey: "song_bestAccuracy_tanah-airku")
        defaults.set(2, forKey: "song_stars_tanah-airku")
        defaults.set(true, forKey: "song_fullCombo_tanah-airku")
        XCTAssertEqual(store.songBestScore("tanah-airku"), 12_345)
        XCTAssertEqual(store.songBestAccuracy("tanah-airku"), 87.5)
        XCTAssertEqual(store.songStars("tanah-airku"), 2)
        XCTAssertTrue(store.isSongFullCombo("tanah-airku"))
    }

    func testLabelsInPerformDefaultsToOffAndPersists() {
        XCTAssertFalse(store.labelsInPerform)
        store.labelsInPerform = true
        XCTAssertTrue(store.labelsInPerform)
        XCTAssertTrue(defaults.bool(forKey: "settings_labelsInPerform"))
    }

    func testEverySongHasADistinctKeySpace() {
        for song in SongLibrary.all {
            store.setSongPracticed(song.id)
        }
        XCTAssertTrue(SongLibrary.all.allSatisfy { store.isSongPracticed($0.id) })
        XCTAssertEqual(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("song_practiced_") }.count, 18)
    }
}

@MainActor
final class AppRouterTests: XCTestCase {

    func testStageSetupRouteHasCampaignDefaults() {
        XCTAssertEqual(Route.stageSetup(songId: "x"), Route.stageSetup(songId: "x", campaignStageId: nil, isBoss: false))
        XCTAssertNotEqual(Route.stageSetup(songId: "x"), Route.stageSetup(songId: "x", campaignStageId: "c1-04", isBoss: false))
    }

    func testPushAndPop() {
        let router = AppRouter()
        router.push(.help)
        router.push(.achievements)
        XCTAssertEqual(router.path, [.help, .achievements])
        router.pop()
        XCTAssertEqual(router.path, [.help])
        router.pop()
        router.pop()                                         // popping an empty stack is harmless
        XCTAssertTrue(router.path.isEmpty)
    }

    func testReplaceTopSwapsTheLastScreen() {
        let router = AppRouter()
        router.push(.songMenu)
        router.push(.stageSetup(songId: "a"))
        router.push(.play(PlayRequest(kind: .rush)))
        router.replaceTop(with: .help)
        XCTAssertEqual(router.path, [.songMenu, .stageSetup(songId: "a"), .help])
        router.pop()
        XCTAssertEqual(router.path.last, .stageSetup(songId: "a"), "Back skips the replaced screen")
    }

    func testReplaceTopOnAnEmptyStackJustPushes() {
        let router = AppRouter()
        router.replaceTop(with: .help)
        XCTAssertEqual(router.path, [.help])
    }

    func testPopToKeepsTheTargetOnTop() {
        let router = AppRouter()
        router.push(.songMenu)
        router.push(.help)
        router.push(.achievements)
        router.pop(to: .help)
        XCTAssertEqual(router.path, [.songMenu, .help])
        router.pop(to: .postplay)                            // not on the stack: back to the root
        XCTAssertTrue(router.path.isEmpty)
    }

    func testPlayRequestCarriesTheLabelChoice() {
        let song = PlayRequest.Kind.song(songId: "x", mode: .practice, speed: 0.5, isBoss: false, isSolemn: false, noteLimit: nil)
        XCTAssertNotEqual(PlayRequest(kind: song, showKeyLabels: true), PlayRequest(kind: song, showKeyLabels: false))
        XCTAssertNil(PlayRequest(kind: song).showKeyLabels)
    }
}
