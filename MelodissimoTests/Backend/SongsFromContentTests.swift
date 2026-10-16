import CryptoKit
import XCTest
@testable import Melodissimo

private struct NoBaseline: ContentBaseline {
    var manifestData: Data? { nil }
    var signature: String? { nil }
    func assetURL(sha256: String, fileExtension: String) -> URL? { nil }
}

/// Songs, charts and backing tracks now come from the content store (`BACKEND_PLAN.md` Task B6.3).
final class SongsFromContentTests: XCTestCase {

    private var dir: URL!
    private var original: ContentStore!
    private let key = Curve25519.Signing.PrivateKey()

    override func setUpWithError() throws {
        original = SongLibrary.contentStore
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SongsFromContent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        SongLibrary.contentStore = original
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    /// A store whose active pack is built from `songs` (id, order, chart notes or nil) with the chart files on disk.
    private func fixtureStore(_ songs: [(id: String, order: Int, keys: [Int]?)], status: String = "live") throws -> ContentStore {
        let root = dir.appendingPathComponent("Content")
        let assets = root.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        var assetJSON: [String] = []
        var songJSON: [String] = []
        for s in songs {
            var chartField = ""
            if let keys = s.keys {
                let notes = keys.enumerated().map { #"{"k": \#($1), "b": \#($0), "d": 1}"# }.joined(separator: ",")
                let chart = Data(#"{"id": "\#(s.id)", "title": "\#(s.id)", "bpm": 90, "notes": [\#(notes)]}"#.utf8)
                let sha = ManifestVerifier.sha256Hex(of: chart)
                try chart.write(to: assets.appendingPathComponent("\(sha).json"))
                assetJSON.append(#""chart.\#(s.id)": {"path": "assets/\#(sha).json", "sha256": "\#(sha)", "bytes": \#(chart.count), "kind": "chart"}"#)
                chartField = #", "chart": "chart.\#(s.id)""#
            }
            songJSON.append(#"{"id": "\#(s.id)", "title": {"canonical": "Title \#(s.id)", "en": "Title \#(s.id)"}, "order": \#(s.order), "packId": "extra", "status": "\#(status)"\#(chartField)}"#)
        }
        let manifest = Data(#"{"schemaVersion": 1, "contentVersion": 2, "songs": [\#(songJSON.joined(separator: ","))], "assets": {\#(assetJSON.joined(separator: ","))}}"#.utf8)
        let manifests = root.appendingPathComponent("manifests")
        try FileManager.default.createDirectory(at: manifests, withIntermediateDirectories: true)
        try manifest.write(to: manifests.appendingPathComponent("2.json"))
        try key.signature(for: manifest).base64EncodedString().write(to: manifests.appendingPathComponent("2.json.sig"), atomically: true, encoding: .utf8)
        try Data(#"{"version": 2}"#.utf8).write(to: root.appendingPathComponent("active.json"))
        let store = ContentStore(root: root, baseline: NoBaseline(),
                                 verifier: ManifestVerifier(trustedKeys: [key.publicKey.rawRepresentation.base64EncodedString()]), build: { 57 })
        store.loadActive()
        return store
    }

    // MARK: Legacy songs

    func testTheSixteenLegacySongsResolveIdenticallyWithTheBundledBaseline() throws {
        let legacy = SongLibrary.legacyAll
        XCTAssertEqual(legacy.count, 16)

        let withBaseline = ContentStore(root: dir.appendingPathComponent("Empty"))
        withBaseline.loadActive()
        SongLibrary.contentStore = withBaseline
        XCTAssertEqual(withBaseline.manifestVersion, 0, "the app's baseline is loaded")
        XCTAssertEqual(SongLibrary.all.map(\.id), legacy.map(\.id))
        XCTAssertEqual(SongLibrary.all.map(\.title), legacy.map(\.title))
        XCTAssertEqual(SongLibrary.all.map(\.keyIds), legacy.map(\.keyIds), "same melodies")
        XCTAssertEqual(SongLibrary.all.map(\.isSolemn), legacy.map(\.isSolemn))
        XCTAssertEqual(SongLibrary.all.map(\.notationImage), legacy.map(\.notationImage))
        XCTAssertTrue(SongLibrary.all.allSatisfy { $0.packId == "core" })

        for song in legacy {
            // The chart from the baseline is the chart that used to ship in the bundle.
            let fromStore = SongChart.load(for: song, bundle: .main)
            let url = try XCTUnwrap(Bundle.main.url(forResource: "chart_\(song.id)", withExtension: "json"))
            let bundled = try JSONDecoder().decode(SongChart.self, from: Data(contentsOf: url))
            XCTAssertEqual(fromStore, bundled, song.id)
            XCTAssertNotNil(BackingTrackPlayer.url(for: song.id), "backing for \(song.id)")
        }
    }

    func testAnEmptyContentStoreFallsBackToTheLegacyList() {
        SongLibrary.contentStore = ContentStore(root: dir.appendingPathComponent("None"), baseline: NoBaseline())
        XCTAssertEqual(SongLibrary.all, SongLibrary.legacyAll)
    }

    func testTrophyKeysStayTheCanonicalTitlesOfTheLegacySongs() {
        SongLibrary.contentStore = ContentStore(root: dir.appendingPathComponent("Empty"))
        SongLibrary.contentStore.loadActive()
        XCTAssertEqual(Set(SongLibrary.all.map(\.title)), Set(SongLibrary.legacyAll.map(\.title)))
        XCTAssertNotNil(SongLibrary.song(title: "Halo Halo Bandung"))
    }

    // MARK: Remote songs

    func testARemoteOnlySongAppearsWithItsChartKeysAsMelody() throws {
        SongLibrary.contentStore = try fixtureStore([("lagu-baru", 5, [5, 6, 7, 9]), ("lagu-dua", 7, [8, 8, 9])])
        let song = try XCTUnwrap(SongLibrary.song(id: "lagu-baru"))
        XCTAssertEqual(song.keyIds, [5, 6, 7, 9])
        XCTAssertEqual(song.title, "Title lagu-baru")
        XCTAssertEqual(song.packId, "extra")
        XCTAssertEqual(SongLibrary.all.map(\.id), ["lagu-baru", "lagu-dua"])
        XCTAssertEqual(SongChart.load(for: song).notes.map(\.k), song.keyIds)
        XCTAssertNil(song.sheet(store: SongLibrary.contentStore), "no sheet image, the app draws it from the chart")
    }

    func testARemoteSongWithoutAChartIsLeftOut() throws {
        SongLibrary.contentStore = try fixtureStore([("with-chart", 1, [5, 6]), ("no-chart", 2, nil)])
        XCTAssertEqual(SongLibrary.all.map(\.id), ["with-chart"])
    }

    func testHiddenRemoteSongsAreNotListed() throws {
        SongLibrary.contentStore = try fixtureStore([("a", 1, [5])], status: "hidden")
        XCTAssertEqual(SongLibrary.all, SongLibrary.legacyAll, "nothing visible: legacy list")
    }

    func testTheListIsRebuiltWhenANewPackGoesLive() throws {
        let first = try fixtureStore([("first", 1, [5, 6])])
        SongLibrary.contentStore = first
        XCTAssertEqual(SongLibrary.all.map(\.id), ["first"])
        // A new release is activated: the cache must not serve the old list.
        let manifest = Data(#"{"schemaVersion": 1, "contentVersion": 3, "songs": [{"id": "second", "title": {"canonical": "S", "en": "S"}, "order": 1, "packId": "extra"}]}"#.utf8)
        let manifests = dir.appendingPathComponent("Content/manifests")
        try manifest.write(to: manifests.appendingPathComponent("3.json"))
        try key.signature(for: manifest).base64EncodedString().write(to: manifests.appendingPathComponent("3.json.sig"), atomically: true, encoding: .utf8)
        XCTAssertTrue(first.activate(version: 3))
        let rebuilt = expectation(description: "list rebuilt")
        DispatchQueue.main.async {
            XCTAssertEqual(SongLibrary.all, SongLibrary.legacyAll, "the new pack's only song has no chart, so the legacy list is used")
            rebuilt.fulfill()
        }
        wait(for: [rebuilt], timeout: 2)
    }

    // MARK: Campaign

    func testEveryCampaignSongExistsInTheLibrary() {
        let ids = Set(SongLibrary.all.map(\.id))
        for stage in CampaignCatalog.allStages {
            switch stage.kind {
            case .song(songId: let id), .boss(songId: let id), .finale(songId: let id):
                XCTAssertTrue(ids.contains(id), "campaign stage \(stage.id) needs song \(id)")
            default:
                break
            }
        }
    }
}
