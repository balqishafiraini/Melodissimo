import XCTest
@testable import Melodissimo

final class SongChartTests: XCTestCase {

    private var sample: Song { SongLibrary.song(title: "Hari Merdeka")! }

    // MARK: Slugs and library

    func testSlugExamples() {
        XCTAssertEqual(SongLibrary.slug(for: "Halo Halo Bandung"), "halo-halo-bandung")
        XCTAssertEqual(SongLibrary.slug(for: "Dari Sabang Sampai Merauke"), "dari-sabang-sampai-merauke")
        XCTAssertEqual(SongLibrary.slug(for: "Indonesia Raya"), "indonesia-raya")
        XCTAssertEqual(SongLibrary.slug(for: "Rock  &  Roll"), "rock-roll")
        XCTAssertEqual(SongLibrary.slug(for: "Lagu 17 Agustus"), "lagu-17-agustus")
    }

    func testLibraryHasAllSixteenSongsWithUniqueSlugs() {
        let songs = SongLibrary.all
        XCTAssertEqual(songs.count, 16)
        XCTAssertEqual(Set(songs.map(\.id)).count, 16)
        for song in songs {
            XCTAssertFalse(song.keyIds.isEmpty, song.title)
            XCTAssertTrue(song.keyIds.allSatisfy { (1...32).contains($0) }, song.title)
            XCTAssertNotNil(SongLibrary.song(id: song.id))
            XCTAssertEqual(SongLibrary.song(title: song.title), song)
        }
    }

    func testOnlyTheThreeSolemnSongsAreSolemn() {
        let solemn = SongLibrary.all.filter(\.isSolemn).map(\.title)
        XCTAssertEqual(Set(solemn), ["Indonesia Raya", "Mengheningkan Cipta", "Gugur Bunga"])
    }

    // MARK: Default chart

    func testAllSixteenSongsLoadAChartMatchingTheirMelody() {
        for song in SongLibrary.all {
            let chart = SongChart.load(for: song)
            XCTAssertEqual(chart.id, song.id)
            XCTAssertEqual(chart.notes.count, song.keyIds.count, song.title)
            XCTAssertTrue(chart.isValid, song.title)
            XCTAssertTrue(chart.matchesMelody(of: song), "\(song.title): chart keys differ from the melody")
            XCTAssertNotNil(chart.offset, "\(song.title): chart is not synced to its backing track")
            XCTAssertTrue(BackingTrackPlayer.isAvailable(for: song.id), "\(song.title): bgm_\(song.id).m4a is not bundled")
        }
    }

    func testDefaultChartIsOneNotePerBeat() {
        let song = sample
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
        let chart = SongChart.defaultChart(for: sample)
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
        { "id": "sample-benderaku", "title": "Berkibarlah Benderaku", "bpm": 96,
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
        let song = sample
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
        let song = sample
        let empty = try makeBundle(containing: [:])
        XCTAssertEqual(SongChart.load(for: song, bundle: empty), SongChart.defaultChart(for: song))

        let garbage = try makeBundle(containing: ["chart_\(song.id).json": "not json"])
        XCTAssertEqual(SongChart.load(for: song, bundle: garbage), SongChart.defaultChart(for: song))

        let invalidKey = try makeBundle(containing: [
            "chart_\(song.id).json": #"{ "id": "x", "title": "X", "bpm": 90, "notes": [ { "k": 99, "b": 0, "d": 1 } ] }"#
        ])
        XCTAssertEqual(SongChart.load(for: song, bundle: invalidKey), SongChart.defaultChart(for: song))
    }

    // MARK: Chart format v2

    private func v2(_ extra: (inout SongChart) -> Void = { _ in }) -> SongChart {
        var chart = SongChart(id: "t", title: "T", bpm: 120,
                              notes: [ChartNote(k: 5, b: 0, d: 1), ChartNote(k: 6, b: 2, d: 2)])
        extra(&chart)
        return chart
    }

    func testV1JSONDecodesWithNilExtras() throws {
        let json = #"{"id":"a","title":"A","bpm":96,"notes":[{"k":9,"b":0,"d":1}]}"#
        let chart = try JSONDecoder().decode(SongChart.self, from: Data(json.utf8))
        XCTAssertNil(chart.beatsPerBar)
        XCTAssertNil(chart.offset)
        XCTAssertNil(chart.beatTimes)
        XCTAssertTrue(chart.isValid)
    }

    func testV2JSONDecodes() throws {
        let json = #"{"id":"a","title":"A","bpm":112.4,"beatsPerBar":3,"offset":3.412,"beatTimes":[3.412,3.946,4.48],"notes":[{"k":2,"b":3,"d":0.5}]}"#
        let chart = try JSONDecoder().decode(SongChart.self, from: Data(json.utf8))
        XCTAssertEqual(chart.beatsPerBar, 3)
        XCTAssertEqual(chart.offset ?? 0, 3.412, accuracy: 1e-9)
        XCTAssertEqual(chart.beatTimes?.count, 3)
        XCTAssertTrue(chart.isValid)
    }

    func testSecondsAtBeatWithoutAMapIsLinear() {
        XCTAssertEqual(v2().seconds(atBeat: 3), 1.5, accuracy: 1e-9)
    }

    func testSecondsAtBeatInterpolatesAndExtrapolates() {
        let chart = v2 { $0.offset = 10; $0.beatTimes = [10, 10.5, 11.25] }   // intervals 0.5, 0.75
        XCTAssertEqual(chart.seconds(atBeat: 0), 0, accuracy: 1e-9)
        XCTAssertEqual(chart.seconds(atBeat: 0.5), 0.25, accuracy: 1e-9)
        XCTAssertEqual(chart.seconds(atBeat: 1), 0.5, accuracy: 1e-9)
        XCTAssertEqual(chart.seconds(atBeat: 1.5), 0.875, accuracy: 1e-9)
        XCTAssertEqual(chart.seconds(atBeat: 2), 1.25, accuracy: 1e-9)
        XCTAssertEqual(chart.seconds(atBeat: 3), 2.0, accuracy: 1e-9)    // continues at the last interval
        XCTAssertEqual(chart.seconds(atBeat: -1), -0.5, accuracy: 1e-9)  // continues at the first interval
    }

    func testTimedNotesWithAMapAtHalfSpeed() {
        let chart = v2 { $0.offset = 10; $0.beatTimes = [10, 10.5, 11.25, 12.25, 13.25] }
        let timed = chart.timedNotes(speed: 0.5)
        XCTAssertEqual(timed[0].time, 0, accuracy: 1e-9)
        XCTAssertEqual(timed[0].duration, 1.0, accuracy: 1e-9)              // 0.5 s / 0.5
        XCTAssertEqual(timed[1].time, 2.5, accuracy: 1e-9)                  // beat 2 = 1.25 s / 0.5
        XCTAssertEqual(timed[1].duration, 4.0, accuracy: 1e-9)              // (3.25 - 1.25) / 0.5
    }

    func testTimedNotesWithoutAMapMatchTheOldFormula() {
        let timed = v2().timedNotes(speed: 0.75)
        XCTAssertEqual(timed[1].time, 2 * 60 / (120 * 0.75), accuracy: 1e-9)
        XCTAssertEqual(timed[1].duration, 2 * 60 / (120 * 0.75), accuracy: 1e-9)
    }

    func testIsValidRejectsBadV2Fields() {
        XCTAssertTrue(v2 { $0.offset = 0; $0.beatsPerBar = 4 }.isValid)
        XCTAssertFalse(v2 { $0.offset = -0.1 }.isValid)
        XCTAssertFalse(v2 { $0.beatsPerBar = 0 }.isValid)
        XCTAssertFalse(v2 { $0.beatsPerBar = 13 }.isValid)
        XCTAssertFalse(v2 { $0.offset = 1; $0.beatTimes = [1, 1.5, 1.4] }.isValid)    // decreasing
        XCTAssertFalse(v2 { $0.offset = 1; $0.beatTimes = [1, 1] }.isValid)           // not strictly increasing
        XCTAssertFalse(v2 { $0.offset = 2; $0.beatTimes = [1, 1.5, 2] }.isValid)      // offset mismatch
        XCTAssertFalse(v2 { $0.beatTimes = [1, 1.5, 2] }.isValid)                     // map without offset
        XCTAssertFalse(v2 { $0.offset = 1; $0.beatTimes = [1] }.isValid)              // too short
    }

    func testBackingTime() {
        let chart = v2 { $0.offset = 4 }
        XCTAssertEqual(chart.backingTime(songTime: -2, speed: 1), 2, accuracy: 1e-9)
        XCTAssertEqual(chart.backingTime(songTime: 3, speed: 0.5), 5.5, accuracy: 1e-9)
        XCTAssertEqual(v2().backingTime(songTime: 3, speed: 1), 3, accuracy: 1e-9)    // no offset → 0
    }
}
