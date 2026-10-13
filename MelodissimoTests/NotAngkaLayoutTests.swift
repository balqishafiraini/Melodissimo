import XCTest
@testable import Melodissimo

/// The score sheet's layout, from crafted charts.
final class NotAngkaLayoutTests: XCTestCase {

    private func chart(_ notes: [(Int, Double, Double)], beatsPerBar: Int? = 4) -> SongChart {
        SongChart(id: "t", title: "T", bpm: 100, notes: notes.map { ChartNote(k: $0.0, b: $0.1, d: $0.2) }, beatsPerBar: beatsPerBar)
    }

    private func slots(_ bar: NotAngkaBar) -> [[NotAngkaSymbol]] { bar.beats.map(\.slots) }

    func testWholeBeatsAreSingleSlotsAndHoldsFillTheBeatsAfterANote() {
        let bars = NotAngkaLayout.bars(for: chart([(5, 0, 2), (6, 2, 1), (7, 3, 1)]))
        XCTAssertEqual(bars.count, 1)
        XCTAssertEqual(bars[0].number, 1)
        XCTAssertEqual(slots(bars[0]), [[.note(keyId: 5)], [.hold], [.note(keyId: 6)], [.note(keyId: 7)]])
    }

    func testHalfBeatsSplitABeatInTwo() {
        let bars = NotAngkaLayout.bars(for: chart([(5, 0, 0.5), (6, 0.5, 0.5), (7, 1, 1), (8, 2, 2)]))
        XCTAssertEqual(slots(bars[0])[0], [.note(keyId: 5), .note(keyId: 6)])
        XCTAssertEqual(slots(bars[0])[1], [.note(keyId: 7)])
    }

    func testDottedRhythmUsesFourSlots() {
        // A dotted eighth then a sixteenth: [a - - b]
        let bars = NotAngkaLayout.bars(for: chart([(5, 0, 0.75), (6, 0.75, 0.25), (7, 1, 3)]))
        XCTAssertEqual(slots(bars[0])[0], [.note(keyId: 5), .hold, .hold, .note(keyId: 6)])
    }

    func testARestInsideABeatShowsAsARestSlot() {
        let bars = NotAngkaLayout.bars(for: chart([(5, 0, 0.5), (6, 1, 1), (7, 2, 2)]))
        XCTAssertEqual(slots(bars[0])[0], [.note(keyId: 5), .rest])
    }

    func testATripletUsesThreeSlots() {
        let third = 1.0 / 3
        let bars = NotAngkaLayout.bars(for: chart([(5, 0, third), (6, third, third), (7, 2 * third, third), (8, 1, 3)]))
        XCTAssertEqual(slots(bars[0])[0], [.note(keyId: 5), .note(keyId: 6), .note(keyId: 7)])
    }

    func testAPickupShowsOnlyItsNotesAndTheFirstFullBarIsNumberOne() {
        // One pickup beat (beat 3 of the pickup bar), then a full bar.
        let bars = NotAngkaLayout.bars(for: chart([(5, 3, 1), (6, 4, 1), (7, 5, 1), (8, 6, 1), (9, 7, 1)]))
        XCTAssertEqual(bars.count, 2)
        XCTAssertEqual(bars[0].number, 0)
        XCTAssertEqual(slots(bars[0]), [[.note(keyId: 5)]], "the rests before a pickup are dropped")
        XCTAssertEqual(bars[1].number, 1)
        XCTAssertEqual(bars[1].beats.count, 4)
    }

    func testATieAcrossTheBarLineBecomesAHold() {
        // A note from beat 3 lasting 3 beats runs over the bar line (4/4).
        let bars = NotAngkaLayout.bars(for: chart([(5, 0, 1), (6, 1, 1), (7, 2, 1), (8, 3, 3), (9, 6, 2)]))
        XCTAssertEqual(slots(bars[0]).last, [.note(keyId: 8)])
        XCTAssertEqual(slots(bars[1])[0], [.hold])
        XCTAssertEqual(slots(bars[1])[1], [.hold])
        XCTAssertEqual(slots(bars[1])[2], [.note(keyId: 9)])
    }

    func testThreeFourBarsHoldThreeBeats() {
        let notes = (0..<7).map { (5, Double($0), 1.0) }
        let bars = NotAngkaLayout.bars(for: chart(notes, beatsPerBar: 3))
        XCTAssertEqual(bars.map { $0.beats.count }, [3, 3, 1])
    }

    func testGlyphPartsFollowTheLabels() {
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: NoteCatalog.id(forLabel: "5.")!), .init(digit: "5", dotsAbove: 0, dotsBelow: 1, isSharp: false))
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: NoteCatalog.id(forLabel: "1˙˙")!), .init(digit: "1", dotsAbove: 2, dotsBelow: 0, isSharp: false))
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: NoteCatalog.id(forLabel: "4˙#")!), .init(digit: "4", dotsAbove: 1, dotsBelow: 0, isSharp: true))
        XCTAssertEqual(NotAngkaLayout.glyph(forKeyId: NoteCatalog.id(forLabel: "4.#")!), .init(digit: "4", dotsAbove: 0, dotsBelow: 1, isSharp: true))
    }

    func testEveryBundledChartLaysOutIntoWholeBars() {
        for song in SongLibrary.all {
            let chart = SongChart.load(for: song)
            let bars = NotAngkaLayout.bars(for: chart)
            let perBar = chart.beatsPerBar ?? 4
            XCTAssertFalse(bars.isEmpty, song.title)
            for bar in bars.dropFirst().dropLast() {
                XCTAssertEqual(bar.beats.count, perBar, "\(song.title) bar \(bar.number)")
            }
            let noteSlots = bars.flatMap(\.beats).flatMap(\.slots).filter { if case .note = $0 { return true } else { return false } }
            XCTAssertEqual(noteSlots.count, chart.notes.count, "\(song.title): every note appears once on the sheet")
        }
    }
}
