import XCTest
@testable import Melodissimo

final class SongChartTests: XCTestCase {

    private var berkibarlah: Song { SongLibrary.song(title: "Berkibarlah Benderaku")! }

    // MARK: Slugs and library

    func testSlugExamples() {
        XCTAssertEqual(SongLibrary.slug(for: "Halo Halo Bandung"), "halo-halo-bandung")
        XCTAssertEqual(SongLibrary.slug(for: "Dari Sabang Sampai Merauke"), "dari-sabang-sampai-merauke")
        XCTAssertEqual(SongLibrary.slug(for: "Indonesia Raya"), "indonesia-raya")
        XCTAssertEqual(SongLibrary.slug(for: "Rock  &  Roll"), "rock-roll")
        XCTAssertEqual(SongLibrary.slug(for: "Lagu 17 Agustus"), "lagu-17-agustus")
    }

    func testLibraryHasAllEighteenSongsWithUniqueSlugs() {
        let songs = SongLibrary.all
        XCTAssertEqual(songs.count, 18)
        XCTAssertEqual(Set(songs.map(\.id)).count, 18)
        for song in songs {
            XCTAssertFalse(song.keyIds.isEmpty, song.title)
            XCTAssertTrue(song.keyIds.allSatisfy { (1...32).contains($0) }, song.title)
            XCTAssertNotNil(SongLibrary.song(id: song.id))
            XCTAssertEqual(SongLibrary.song(title: song.title), song)
        }
    }

    func testOnlyTheTwoNationalSongsAreSolemn() {
        let solemn = SongLibrary.all.filter(\.isSolemn).map(\.title)
        XCTAssertEqual(Set(solemn), ["Indonesia Raya", "Mengheningkan Cipta"])
    }

    // MARK: Default chart

    func testAllEighteenSongsLoadAChartMatchingTheirMelody() {
        for song in SongLibrary.all {
            let chart = SongChart.load(for: song)
            XCTAssertEqual(chart.id, song.id)
            XCTAssertEqual(chart.notes.count, song.keyIds.count, song.title)
            XCTAssertTrue(chart.isValid, song.title)
            XCTAssertTrue(chart.matchesMelody(of: song), "\(song.title): chart keys differ from the melody")
        }
    }

    func testDefaultChartIsOneNotePerBeat() {
        let song = berkibarlah
        let chart = SongChart.defaultChart(for: song)
        XCTAssertEqual(chart.bpm, 90)
        XCTAssertEqual(chart.notes.count, song.keyIds.count)
        XCTAssertEqual(chart.notes.map(\.k), song.keyIds)
        XCTAssertEqual(chart.notes.map(\.b), (0..<song.keyIds.count).map(Double.init))
        XCTAssertTrue(chart.notes.allSatisfy { $0.d == 1 })
        XCTAssertTrue(zip(chart.notes, chart.notes.dropFirst()).allSatisfy { $0.b < $1.b })
    }

    // MARK: Timing

    func testTimedNotesUseBeatsOverTempoAndSpeed() {
        let chart = SongChart(id: "t", title: "T", bpm: 120,
                              notes: [ChartNote(k: 5, b: 0, d: 1), ChartNote(k: 6, b: 1.5, d: 0.5)])
        let normal = chart.timedNotes(speed: 1)
        XCTAssertEqual(normal.map(\.index), [0, 1])
        XCTAssertEqual(normal.map(\.keyId), [5, 6])
        XCTAssertEqual(normal[0].time, 0, accuracy: 1e-9)
        XCTAssertEqual(normal[1].time, 0.75, accuracy: 1e-9)       // 1.5 beats at 0.5 s per beat
        XCTAssertEqual(normal[1].duration, 0.25, accuracy: 1e-9)
    }

    func testHalfSpeedDoublesTimesAndDurations() {
        let chart = SongChart.defaultChart(for: berkibarlah)
        let normal = chart.timedNotes(speed: 1)
        let slow = chart.timedNotes(speed: 0.5)
        XCTAssertEqual(normal.count, slow.count)
        for (a, b) in zip(normal, slow) {
            XCTAssertEqual(b.time, a.time * 2, accuracy: 1e-9)
            XCTAssertEqual(b.duration, a.duration * 2, accuracy: 1e-9)
        }
    }

    // MARK: JSON

    func testHandWrittenJSONDecodes() throws {
        let json = """
        { "id": "berkibarlah-benderaku", "title": "Berkibarlah Benderaku", "bpm": 96,
          "notes": [ { "k": 9, "b": 0, "d": 1 }, { "k": 9, "b": 1, "d": 0.5 } ] }
        """
        let chart = try JSONDecoder().decode(SongChart.self, from: Data(json.utf8))
        XCTAssertEqual(chart.bpm, 96)
        XCTAssertEqual(chart.notes, [ChartNote(k: 9, b: 0, d: 1), ChartNote(k: 9, b: 1, d: 0.5)])
        XCTAssertTrue(chart.isValid)
    }

    func testChartRoundTripsThroughJSON() throws {
        let chart = SongChart(id: "x", title: "X", bpm: 100.5,
                              notes: [ChartNote(k: 1, b: 0, d: 1.5), ChartNote(k: 32, b: 2.25, d: 0.25)])
        let data = try JSONEncoder().encode(chart)
        XCTAssertEqual(try JSONDecoder().decode(SongChart.self, from: data), chart)
    }

    func testValidationRejectsBrokenCharts() {
        func chart(bpm: Double = 90, _ notes: [ChartNote]) -> SongChart {
            SongChart(id: "x", title: "X", bpm: bpm, notes: notes)
        }
        XCTAssertFalse(chart([]).isValid)
        XCTAssertFalse(chart(bpm: 0, [ChartNote(k: 1, b: 0, d: 1)]).isValid)
        XCTAssertFalse(chart([ChartNote(k: 33, b: 0, d: 1)]).isValid)
        XCTAssertFalse(chart([ChartNote(k: 0, b: 0, d: 1)]).isValid)
        XCTAssertFalse(chart([ChartNote(k: 1, b: 0, d: 0)]).isValid)
        XCTAssertFalse(chart([ChartNote(k: 1, b: 1, d: 1), ChartNote(k: 2, b: 1, d: 1)]).isValid, "beats must strictly increase")
        XCTAssertFalse(chart([ChartNote(k: 1, b: 2, d: 1), ChartNote(k: 2, b: 1, d: 1)]).isValid)
        XCTAssertTrue(chart([ChartNote(k: 1, b: 0, d: 1), ChartNote(k: 2, b: 0.5, d: 1)]).isValid)
    }

    // MARK: Loading from a bundle

    private func makeBundle(containing files: [String: String]) throws -> Bundle {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        for (name, contents) in files {
            try contents.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return try XCTUnwrap(Bundle(path: dir.path))
    }

    func testLoadPrefersABundledChartOverTheDefault() throws {
        let song = berkibarlah
        let json = """
        { "id": "\(song.id)", "title": "\(song.title)", "bpm": 120,
          "notes": [ { "k": 9, "b": 0, "d": 2 }, { "k": 7, "b": 2, "d": 1 } ] }
        """
        let bundle = try makeBundle(containing: ["chart_\(song.id).json": json])
        let chart = SongChart.load(for: song, bundle: bundle)
        XCTAssertEqual(chart.bpm, 120)
        XCTAssertEqual(chart.notes.count, 2)
    }

    func testLoadFallsBackToTheDefaultWhenTheFileIsMissingOrBroken() throws {
        let song = berkibarlah
        let empty = try makeBundle(containing: [:])
        XCTAssertEqual(SongChart.load(for: song, bundle: empty), SongChart.defaultChart(for: song))

        let garbage = try makeBundle(containing: ["chart_\(song.id).json": "not json"])
        XCTAssertEqual(SongChart.load(for: song, bundle: garbage), SongChart.defaultChart(for: song))

        let invalidKey = try makeBundle(containing: [
            "chart_\(song.id).json": #"{ "id": "x", "title": "X", "bpm": 90, "notes": [ { "k": 99, "b": 0, "d": 1 } ] }"#
        ])
        XCTAssertEqual(SongChart.load(for: song, bundle: invalidKey), SongChart.defaultChart(for: song))
    }
}
