import XCTest
@testable import Melodissimo

/// The scoreboard split (STABILITY_PLAN S5): the engine's numbers live on `StageScoreboard`, and `onJudgment`
/// reports each judgment at the moment it is made.
final class StageScoreboardTests: XCTestCase {

    private let start: CFTimeInterval = 100

    private func makeEngine(_ mode: StageMode, keys: [Int] = [5, 6, 7]) -> RhythmEngine {
        let chart = SongChart(id: "test", title: "Test", bpm: 60,
                              notes: keys.enumerated().map { ChartNote(k: $1, b: Double($0), d: 1) })
        let engine = RhythmEngine(chart: chart, mode: mode, soundPlayer: { _ in }, soundStopper: { _ in })
        engine.start(now: start)
        return engine
    }

    private func hostTime(of index: Int, in engine: RhythmEngine) -> CFTimeInterval {
        start + engine.countInDuration + engine.notes[index].time
    }

    func testEngineNumbersAreTheScoreboardsNumbers() {
        let engine = makeEngine(.perform)
        engine.press(keyId: 5, now: hostTime(of: 0, in: engine))
        engine.press(keyId: 9, now: hostTime(of: 0, in: engine) + 0.1)
        XCTAssertEqual(engine.score, engine.scoreboard.score)
        XCTAssertEqual(engine.combo, 0)
        XCTAssertEqual(engine.maxCombo, 1)
        XCTAssertEqual(engine.counts.perfect, 1)
        XCTAssertEqual(engine.wrongPresses, 1)
        XCTAssertEqual(engine.scoreboard.judgedCount, 1)
        XCTAssertEqual(engine.scoreboard.lastWrongPress?.keyId, 9)
    }

    func testJudgedCountFollowsEveryWayANoteIsJudged() {
        let perform = makeEngine(.perform)
        perform.press(keyId: 5, now: hostTime(of: 0, in: perform))
        perform.step(now: hostTime(of: 2, in: perform) + 1)          // the other two expire
        XCTAssertEqual(perform.judgedCount, 3)

        let practice = makeEngine(.practice)
        practice.step(now: hostTime(of: 0, in: practice))
        practice.press(keyId: 5, now: hostTime(of: 0, in: practice))
        XCTAssertEqual(practice.judgedCount, 1)

        let listen = makeEngine(.listen)
        listen.step(now: hostTime(of: 1, in: listen) + 0.01)         // notes 0 and 1 are due
        XCTAssertEqual(listen.judgedCount, 2)
    }

    func testRestartResetsTheScoreboard() {
        let engine = makeEngine(.perform)
        engine.press(keyId: 5, now: hostTime(of: 0, in: engine))
        engine.restart(now: 200)
        XCTAssertEqual(engine.score, 0)
        XCTAssertEqual(engine.scoreboard.judgedCount, 0)
        XCTAssertNil(engine.scoreboard.lastWrongPress)
    }

    func testTheSameKeyPressedWronglyTwiceIsTwoDistinctFlashes() {
        let board = StageScoreboard()
        board.registerWrongPress(keyId: 4, breaksCombo: false)
        let first = board.lastWrongPress
        board.registerWrongPress(keyId: 4, breaksCombo: false)
        XCTAssertNotEqual(first, board.lastWrongPress)
        XCTAssertEqual(board.wrongPresses, 2)
    }

    // MARK: onJudgment

    func testOnJudgmentFiresOncePerHit() {
        let engine = makeEngine(.perform)
        var seen: [Judgment?] = []
        engine.onJudgment = { seen.append($0) }
        engine.press(keyId: 5, now: hostTime(of: 0, in: engine))
        engine.press(keyId: 6, now: hostTime(of: 1, in: engine) + 0.1)
        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(seen[0], .perfect)
        XCTAssertEqual(seen[1], .great)
    }

    func testOnJudgmentFiresOncePerMissEvenInTheSameFrame() {
        let engine = makeEngine(.perform)
        var seen: [Judgment?] = []
        engine.onJudgment = { seen.append($0) }
        engine.step(now: hostTime(of: 2, in: engine) + 1)            // all three expire in one step
        XCTAssertEqual(seen.count, 3)
        XCTAssertTrue(seen.allSatisfy { $0 == .miss })
        engine.step(now: hostTime(of: 2, in: engine) + 2)
        XCTAssertEqual(seen.count, 3, "an already judged note is never reported twice")
    }

    func testOnJudgmentReportsAWrongPressWithNil() {
        let engine = makeEngine(.perform)
        var seen: [Judgment?] = []
        engine.onJudgment = { seen.append($0) }
        engine.press(keyId: 12, now: hostTime(of: 0, in: engine))
        XCTAssertEqual(seen.count, 1)
        XCTAssertNil(seen[0] ?? nil)
        XCTAssertEqual(engine.wrongPresses, 1)
    }

    func testPracticeReportsWrongPressesButNotCorrectOnes() {
        let engine = makeEngine(.practice)
        var seen: [Judgment?] = []
        engine.onJudgment = { seen.append($0) }
        engine.step(now: hostTime(of: 0, in: engine))
        engine.press(keyId: 9, now: hostTime(of: 0, in: engine))
        engine.press(keyId: 5, now: hostTime(of: 0, in: engine))
        XCTAssertEqual(seen.count, 1)
        XCTAssertEqual(engine.scoreboard.lastWrongPress?.keyId, 9)
    }

    func testAPressDuringTheCountInMakesNoSound() {
        let engine = makeEngine(.perform)
        var seen = 0
        engine.onJudgment = { _ in seen += 1 }
        engine.press(keyId: 9, now: start + 0.5)
        XCTAssertEqual(seen, 0)
    }
}
