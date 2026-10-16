import XCTest
@testable import Melodissimo

/// Exports today's song list for the backend repo (`mdm content import-ios`, `BACKEND_PLAN.md` Task B1.2).
/// Runs only when `MELODISSIMO_EXPORT_DIR` is set:
///
///     TEST_RUNNER_MELODISSIMO_EXPORT_DIR=/tmp/melodissimo-export xcodebuild test -project Melodissimo.xcodeproj \
///       -scheme Melodissimo -destination '<sim>' -only-testing:MelodissimoTests/ContentExportTests
final class ContentExportTests: XCTestCase {

    /// The `song.json` for one song, in the shape of `song.schema.json`.
    static func songJSON(_ song: Song, index: Int) -> [String: Any] {
        [
            "id": song.id,
            "title": ["canonical": song.title, "id": song.title, "en": song.title],
            "order": index * 10,
            "packId": "core",
            "isSolemn": song.isSolemn,
            "bundledSheetImage": song.notationImage,
        ]
    }

    func testExportEverySongForTheBackendRepo() throws {
        guard let dir = ProcessInfo.processInfo.environment["MELODISSIMO_EXPORT_DIR"], !dir.isEmpty else {
            throw XCTSkip("set MELODISSIMO_EXPORT_DIR to export the songs")
        }
        let root = URL(fileURLWithPath: dir).appendingPathComponent("songs")
        for (index, song) in SongLibrary.all.enumerated() {
            let folder = root.appendingPathComponent(song.id)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: Self.songJSON(song, index: index),
                                                  options: [.prettyPrinted, .sortedKeys])
            try data.write(to: folder.appendingPathComponent("song.json"))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).count, SongLibrary.all.count)
    }

    func testTheExportedShapeCarriesTheCanonicalTitleAndTheSheetName() throws {
        let song = try XCTUnwrap(SongLibrary.song(id: "halo-halo-bandung"))
        let json = Self.songJSON(song, index: 3)
        XCTAssertEqual((json["title"] as? [String: String])?["canonical"], "Halo Halo Bandung")
        XCTAssertEqual(json["order"] as? Int, 30)
        XCTAssertEqual(json["packId"] as? String, "core")
        XCTAssertEqual(json["bundledSheetImage"] as? String, song.notationImage)
    }
}
