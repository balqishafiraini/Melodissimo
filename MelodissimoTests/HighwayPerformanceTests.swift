import XCTest
import SwiftUI
@testable import Melodissimo

/// A budget check for the note highway: one frame of the real `NoteHighwayView` with a dense chart
/// (more than ten notes on screen) must cost far less than the 16.7 ms a 60 fps frame allows.
/// It renders offscreen with `ImageRenderer`, a fresh renderer per frame, so it is an upper bound
/// of what the display link pays (no GPU, and the view tree is rebuilt every time).
@MainActor
final class HighwayPerformanceTests: XCTestCase {

    /// A chart with a note every eighth of a beat at 120 bpm, so 16 notes fall inside the 2 s approach.
    private func denseChart(noteCount: Int = 80) -> SongChart {
        let keys = [5, 6, 7, 8, 9, 10, 11, 12, 23, 24, 25, 26]
        let notes = (0..<noteCount).map { ChartNote(k: keys[$0 % keys.count], b: Double($0) / 4, d: 0.25) }
        return SongChart(id: "dense", title: "Dense", bpm: 120, notes: notes)
    }

    /// 40-point lanes, one per key id, laid out in a 1,280-point-wide window.
    private func laneFrames() -> [Int: CGRect] {
        Dictionary(uniqueKeysWithValues: (1...32).map { ($0, CGRect(x: CGFloat($0 - 1) * 40, y: 0, width: 38, height: 200)) })
    }

    private func engineWithNotesInView() -> RhythmEngine {
        let engine = RhythmEngine(chart: denseChart(), mode: .perform, speed: 1, approachTime: 2.0,
                                  soundPlayer: { _ in }, soundStopper: { _ in })
        // Start the song clock 5 s ago so we're mid-song: the notes of the next 2 s are all on screen.
        engine.start(now: CACurrentMediaTime() - 5)
        return engine
    }

    func testTheDenseChartReallyShowsMoreThanTenNotes() {
        let engine = engineWithNotesInView()
        let songTime = engine.songTime(now: CACurrentMediaTime())
        let visible = engine.notes.filter {
            HighwayGeometry.isVisible(noteTime: $0.time, duration: $0.duration, songTime: songTime, approachTime: engine.approachTime)
        }
        XCTAssertGreaterThanOrEqual(visible.count, 10, "the benchmark has to be dense to mean anything")
    }

    func testOneFrameOfTheHighwayWithADenseChartFitsTheFrameBudget() {
        let engine = engineWithNotesInView()
        let flashes = LaneFlashes()
        flashes.press(keyId: 8, at: CACurrentMediaTime())
        flashes.press(keyId: 10, at: CACurrentMediaTime())

        func renderOneFrame() -> UIImage? {
            let view = NoteHighwayView(engine: engine, keyFrames: laneFrames(), showsPopups: true, laneFlashes: flashes)
                .frame(width: 1280, height: 460)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            return renderer.uiImage
        }

        // A first render warms the fonts and caches, like the first frames of a real stage.
        XCTAssertNotNil(renderOneFrame())

        let frames = 60
        let start = CACurrentMediaTime()
        for _ in 0..<frames { _ = renderOneFrame() }
        let millisecondsPerFrame = (CACurrentMediaTime() - start) / Double(frames) * 1000
        print("Highway frame with a dense chart: \(String(format: "%.2f", millisecondsPerFrame)) ms per frame (budget 16.7 ms at 60 fps)")

        XCTAssertLessThan(millisecondsPerFrame, 16.7, "one highway frame must fit in a 60 fps frame")
    }
}
