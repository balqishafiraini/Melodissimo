import XCTest
@testable import Melodissimo

final class ChartQuantizerTests: XCTestCase {

    private func presses(_ pairs: [(Double, Int)]) -> [RecordedPress] {
        pairs.map { RecordedPress(time: $0.0, keyId: $0.1) }
    }

    func testSnapsToTheGridRelativeToTheFirstPress() {
        // 60 bpm = 1 s per beat, half-beat grid.
        let notes = ChartQuantizer.quantize(presses([(10.0, 5), (11.02, 6), (11.46, 7), (12.9, 8), (14.1, 9)]), bpm: 60, grid: 0.5)
        XCTAssertEqual(notes.map(\.k), [5, 6, 7, 8, 9])
        XCTAssertEqual(notes.map(\.b), [0, 1, 1.5, 3, 4])
    }

    func testDurationsRunToTheNextNoteAndTheLastIsTwoBeats() {
        let notes = ChartQuantizer.quantize(presses([(0, 5), (1, 6), (1.5, 7), (3, 8)]), bpm: 60, grid: 0.5)
        XCTAssertEqual(notes.map(\.d), [1, 0.5, 1.5, 2])
    }

    func testQuarterBeatGrid() {
        let notes = ChartQuantizer.quantize(presses([(0, 5), (0.27, 6), (0.49, 7)]), bpm: 60, grid: 0.25)
        XCTAssertEqual(notes.map(\.b), [0, 0.25, 0.5])
    }

    func testTempoChangesTheSpacing() {
        // 120 bpm: 0.5 s per beat, so a press 1 s later is two beats on.
        let notes = ChartQuantizer.quantize(presses([(5, 5), (6, 6)]), bpm: 120, grid: 0.5)
        XCTAssertEqual(notes.map(\.b), [0, 2])
    }

    func testCollidingBeatsArePushedOnSoTheyStrictlyIncrease() {
        // Three presses within the same half beat all round to beat 0.
        let notes = ChartQuantizer.quantize(presses([(0, 5), (0.05, 6), (0.1, 7), (2, 8)]), bpm: 60, grid: 0.5)
        XCTAssertEqual(notes.map(\.b), [0, 0.5, 1, 2])
        XCTAssertTrue(zip(notes, notes.dropFirst()).allSatisfy { $0.b < $1.b })
        XCTAssertTrue(notes.allSatisfy { $0.d > 0 })
    }

    func testAPushedNoteCanCascadeIntoTheNextOne() {
        // Beats would be 0, 0, 0.5 → pushed to 0, 0.5, 1.
        let notes = ChartQuantizer.quantize(presses([(0, 5), (0.1, 6), (0.5, 7)]), bpm: 60, grid: 0.5)
        XCTAssertEqual(notes.map(\.b), [0, 0.5, 1])
    }

    func testEmptyAndInvalidInput() {
        XCTAssertTrue(ChartQuantizer.quantize([], bpm: 90, grid: 0.5).isEmpty)
        XCTAssertTrue(ChartQuantizer.quantize(presses([(0, 5)]), bpm: 0, grid: 0.5).isEmpty)
        XCTAssertTrue(ChartQuantizer.quantize(presses([(0, 5)]), bpm: 90, grid: 0).isEmpty)
        let single = ChartQuantizer.quantize(presses([(3, 5)]), bpm: 90, grid: 0.5)
        XCTAssertEqual(single, [ChartNote(k: 5, b: 0, d: 2)])
    }

    func testQuantizedOutputIsAValidChart() {
        let song = SongLibrary.song(id: "berkibarlah-benderaku")!
        let spb = 60.0 / 96
        let played = song.keyIds.enumerated().map { RecordedPress(time: 100 + Double($0.offset) * spb + 0.03, keyId: $0.element) }
        let chart = ChartQuantizer.chart(for: song, bpm: 96, notes: ChartQuantizer.quantize(played, bpm: 96, grid: 0.5))
        XCTAssertTrue(chart.isValid)
        XCTAssertTrue(chart.matchesMelody(of: song))
        XCTAssertEqual(chart.notes.map(\.b), (0..<song.keyIds.count).map(Double.init), "a steady player gets one note per beat")
    }

    // MARK: JSON and files

    func testJSONIsPrettyPrintedWithSortedKeysAndRoundTrips() throws {
        let chart = SongChart(id: "x", title: "X", bpm: 96, notes: [ChartNote(k: 9, b: 0, d: 1), ChartNote(k: 7, b: 1, d: 0.5)])
        let json = try ChartQuantizer.json(for: chart)
        XCTAssertTrue(json.contains("\n"), "pretty printed")
        let bpmIndex = try XCTUnwrap(json.range(of: "\"bpm\""))
        let idIndex = try XCTUnwrap(json.range(of: "\"id\""))
        let notesIndex = try XCTUnwrap(json.range(of: "\"notes\""))
        let titleIndex = try XCTUnwrap(json.range(of: "\"title\""))
        XCTAssertTrue(bpmIndex.lowerBound < idIndex.lowerBound && idIndex.lowerBound < notesIndex.lowerBound && notesIndex.lowerBound < titleIndex.lowerBound, "sorted keys")
        XCTAssertEqual(try JSONDecoder().decode(SongChart.self, from: Data(json.utf8)), chart)
    }

    func testWritesChartSlugJSONAndSongChartLoadsItBack() throws {
        let song = SongLibrary.song(id: "merah-putih")!
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let notes = song.keyIds.enumerated().map { ChartNote(k: $0.element, b: Double($0.offset) * 0.5, d: 0.5) }
        let chart = ChartQuantizer.chart(for: song, bpm: 110, notes: notes)
        let url = try ChartQuantizer.write(chart, for: song, to: dir)
        XCTAssertEqual(url.lastPathComponent, "chart_merah-putih.json")
        XCTAssertEqual(ChartQuantizer.fileName(for: song), "chart_merah-putih.json")

        let loaded = SongChart.load(for: song, bundle: try XCTUnwrap(Bundle(path: dir.path)))
        XCTAssertEqual(loaded, chart, "what the recorder writes is what the game loads")
    }
}

final class ChartRecorderViewModelTests: XCTestCase {

    private let song = SongLibrary.song(id: "berkibarlah-benderaku")!      // 5, 5, 3, 1, 2, …

    private func recorder() -> ChartRecorderViewModel {
        let model = ChartRecorderViewModel(song: song)
        model.bpm = 60                   // 1 s per beat
        model.grid = 0.5
        return model
    }

    func testPressesDuringTheFourBeatCountInAreIgnored() {
        let model = recorder()
        model.start(now: 100)
        XCTAssertTrue(model.isCountingIn(now: 103.9))
        model.keyDown(9, now: 103.9)
        XCTAssertEqual(model.recordedCount, 0)
        XCTAssertFalse(model.isCountingIn(now: 104.0))
        model.keyDown(9, now: 104.0)
        XCTAssertEqual(model.recordedCount, 1)
    }

    func testMetronomeBeatsAndProgress() {
        let model = recorder()
        model.start(now: 100)
        XCTAssertEqual(model.metronomeBeat(now: 100.2), 0)
        XCTAssertEqual(model.metronomeBeat(now: 102.5), 2)
        XCTAssertEqual(model.beatProgress(now: 102.25), 0.25, accuracy: 1e-9)
        XCTAssertEqual(model.beatProgress(now: 50), 0, "not recording yet")
    }

    func testOnlyTheExpectedKeyIsRecordedAndAWrongOneFlashes() {
        let model = recorder()
        model.start(now: 0)
        XCTAssertEqual(model.expectedKeyId, 9)
        model.keyDown(5, now: 5)                     // wrong
        XCTAssertEqual(model.wrongKeyId, 5)
        XCTAssertEqual(model.recordedCount, 0)
        model.clearWrongKey()
        XCTAssertNil(model.wrongKeyId)
        model.keyDown(9, now: 6)
        XCTAssertEqual(model.recordedCount, 1)
        XCTAssertEqual(model.expectedKeyId, 9)       // the melody's second note is also a 5
        model.keyDown(9, now: 7)
        XCTAssertEqual(model.expectedKeyId, 7)
    }

    func testStopQuantizesTheRecordingIntoAChart() throws {
        let model = recorder()
        model.start(now: 0)
        // count-in 0…4 s, then 5, 5, 3 played a beat apart.
        model.keyDown(9, now: 4.0)
        model.keyDown(9, now: 5.02)
        model.keyDown(7, now: 5.99)
        model.stop()
        XCTAssertEqual(model.phase, .finished)
        let chart = try XCTUnwrap(model.chart)
        XCTAssertEqual(chart.id, song.id)
        XCTAssertEqual(chart.bpm, 60)
        XCTAssertEqual(chart.notes, [ChartNote(k: 9, b: 0, d: 1), ChartNote(k: 9, b: 1, d: 1), ChartNote(k: 7, b: 2, d: 2)])
    }

    func testRecordingTheWholeSongStopsByItself() throws {
        let model = recorder()
        model.start(now: 0)
        for (index, key) in song.keyIds.enumerated() {
            model.keyDown(key, now: 4 + Double(index))
        }
        XCTAssertEqual(model.phase, .finished)
        XCTAssertNil(model.expectedKeyId)
        let chart = try XCTUnwrap(model.chart)
        XCTAssertTrue(chart.isValid)
        XCTAssertTrue(chart.matchesMelody(of: song))
    }

    func testStoppingWithNothingRecordedGivesNoChart() {
        let model = recorder()
        model.start(now: 0)
        model.stop()
        XCTAssertEqual(model.phase, .finished)
        XCTAssertNil(model.chart)
    }

    func testResetReturnsToSetup() {
        let model = recorder()
        model.start(now: 0)
        model.keyDown(9, now: 4)
        model.reset()
        XCTAssertEqual(model.phase, .setup)
        XCTAssertEqual(model.recordedCount, 0)
        XCTAssertEqual(model.expectedKeyId, 9)
    }

    func testPressesAreIgnoredOutsideARecording() {
        let model = recorder()
        model.keyDown(9, now: 10)
        XCTAssertEqual(model.recordedCount, 0)
        model.start(now: 0)
        model.stop()
        model.keyDown(9, now: 10)
        XCTAssertEqual(model.recordedCount, 0)
    }
}
