import XCTest
@testable import Melodissimo

/// Drives `RhythmEngine` with fake host times, so no display link or audio is involved.
///
/// The default chart is 60 bpm (one beat per second) with keys 5, 6, 7 at beats 0, 1, 2.
/// Started at host time 100 with a 3-beat count-in, the notes land at host times 103, 104 and 105.
final class RhythmEngineTests: XCTestCase {

    private let start: CFTimeInterval = 100

    private func chart(keys: [Int] = [5, 6, 7], bpm: Double = 60) -> SongChart {
        SongChart(id: "test", title: "Test", bpm: bpm,
                  notes: keys.enumerated().map { ChartNote(k: $1, b: Double($0), d: 1) })
    }

    private func makeEngine(_ mode: StageMode,
                            keys: [Int] = [5, 6, 7],
                            speed: Double = 1,
                            offsetMs: Int = 0,
                            played: Recorder = Recorder()) -> RhythmEngine {
        let engine = RhythmEngine(chart: chart(keys: keys), mode: mode, speed: speed, audioOffsetMs: offsetMs,
                                  soundPlayer: { played.played.append($0) },
                                  soundStopper: { played.stopped.append($0) })
        engine.start(now: start)
        return engine
    }

    /// Host time at which note `index` is due.
    private func hostTime(of index: Int, in engine: RhythmEngine) -> CFTimeInterval {
        start + engine.countInDuration + engine.notes[index].time
    }

    final class Recorder {
        var played: [String] = []
        var stopped: [String] = []
    }

    // MARK: Judge

    func testJudgeWindowBoundaries() {
        XCTAssertEqual(Judge.judge(delta: 0), .perfect)
        XCTAssertEqual(Judge.judge(delta: 0.070), .perfect)
        XCTAssertEqual(Judge.judge(delta: -0.070), .perfect)
        XCTAssertEqual(Judge.judge(delta: 0.0701), .great)
        XCTAssertEqual(Judge.judge(delta: 0.130), .great)
        XCTAssertEqual(Judge.judge(delta: -0.130), .great)
        XCTAssertEqual(Judge.judge(delta: 0.1301), .good)
        XCTAssertEqual(Judge.judge(delta: 0.200), .good)
        XCTAssertEqual(Judge.judge(delta: -0.200), .good)
        XCTAssertNil(Judge.judge(delta: 0.2001))
        XCTAssertNil(Judge.judge(delta: -0.2001))
    }

    func testPoints() {
        XCTAssertEqual(Judge.points(for: .perfect), 300)
        XCTAssertEqual(Judge.points(for: .great), 200)
        XCTAssertEqual(Judge.points(for: .good), 100)
        XCTAssertEqual(Judge.points(for: .miss), 0)
    }

    func testComboMultiplierStepsAtTenTwentyAndThirty() {
        let expected = [(0, 1), (1, 1), (9, 1), (10, 2), (19, 2), (20, 3), (29, 3), (30, 4), (31, 4), (99, 4)]
        for (combo, multiplier) in expected {
            XCTAssertEqual(Judge.multiplier(forCombo: combo), multiplier, "combo \(combo)")
        }
    }

    func testAccuracyFormula() {
        var counts = JudgmentCounts()
        counts.perfect = 2
        counts.great = 1
        counts.good = 1
        // (2×1 + 1×0.75 + 1×0.4 − 2×0.25) / 4 × 100
        XCTAssertEqual(Judge.accuracy(counts: counts, wrongPresses: 2, totalNotes: 4), 66.25, accuracy: 1e-9)
        XCTAssertEqual(Judge.accuracy(counts: JudgmentCounts(miss: 4), wrongPresses: 10, totalNotes: 4), 0, "never negative")
        XCTAssertEqual(Judge.accuracy(counts: JudgmentCounts(perfect: 4), wrongPresses: 0, totalNotes: 4), 100)
        XCTAssertEqual(Judge.accuracy(counts: JudgmentCounts(), wrongPresses: 0, totalNotes: 0), 0)
    }

    func testStarThresholds() {
        XCTAssertEqual(Judge.stars(forAccuracy: 59.99), 0)
        XCTAssertEqual(Judge.stars(forAccuracy: 60), 1)
        XCTAssertEqual(Judge.stars(forAccuracy: 79.99), 1)
        XCTAssertEqual(Judge.stars(forAccuracy: 80), 2)
        XCTAssertEqual(Judge.stars(forAccuracy: 94.99), 2)
        XCTAssertEqual(Judge.stars(forAccuracy: 95), 3)
        XCTAssertEqual(Judge.stars(forAccuracy: 100), 3)
    }

    func testSpeedCapsStars() {
        for (speed, cap) in [(0.5, 1), (0.75, 2), (1.0, 3)] {
            let engine = makeEngine(.perform, speed: speed)
            for index in 0..<3 { engine.press(keyId: engine.notes[index].keyId, now: hostTime(of: index, in: engine)) }
            XCTAssertEqual(engine.accuracy, 100)
            XCTAssertEqual(engine.stars(speedCapped: false), 3, "speed \(speed)")
            XCTAssertEqual(engine.stars(speedCapped: true), cap, "speed \(speed)")
        }
    }

    // MARK: Lifecycle and timing

    func testCountInThenPlaying() {
        let engine = makeEngine(.perform)
        XCTAssertEqual(engine.phase, .countIn)
        XCTAssertEqual(engine.songTime(now: start), -3, accuracy: 1e-9)
        XCTAssertEqual(engine.countInDuration, 3, accuracy: 1e-9)
        engine.step(now: 102.9)
        XCTAssertEqual(engine.phase, .countIn)
        engine.step(now: 103.0)
        XCTAssertEqual(engine.phase, .playing)
    }

    func testNotBeforeStartAndCountInScalesWithSpeed() {
        let engine = RhythmEngine(chart: chart(), mode: .perform, speed: 0.5)
        XCTAssertEqual(engine.phase, .ready)
        engine.press(keyId: 5, now: 5)
        engine.step(now: 5)
        XCTAssertEqual(engine.phase, .ready)
        XCTAssertEqual(engine.counts.total, 0)
        XCTAssertEqual(engine.countInDuration, 6, accuracy: 1e-9, "3 beats at 30 effective bpm")
        XCTAssertEqual(engine.notes.map(\.time), [0, 2, 4])
    }

    // MARK: Perform: judging

    func testPressesAreJudgedByDistanceFromTheNote() {
        let early = makeEngine(.perform)
        early.press(keyId: 5, now: 102.85)                 // −0.15 s, still in the count-in
        XCTAssertEqual(early.notes[0].judgment, .good)

        let late = makeEngine(.perform)
        late.step(now: 103.0)
        late.press(keyId: 5, now: 103.10)                  // +0.10 s
        XCTAssertEqual(late.notes[0].judgment, .great)

        let exact = makeEngine(.perform)
        exact.step(now: 103.0)
        exact.press(keyId: 5, now: 103.05)                 // +0.05 s
        XCTAssertEqual(exact.notes[0].judgment, .perfect)
        XCTAssertEqual(exact.counts.perfect, 1)
        XCTAssertEqual(exact.combo, 1)
        XCTAssertEqual(exact.score, 300)
        XCTAssertEqual(exact.recentEvents.last, JudgmentEvent(keyId: 5, judgment: .perfect, hostTime: 103.05))
    }

    func testRightKeyOutsideTheWindowIsAWrongPressNotAHit() {
        let engine = makeEngine(.perform)
        engine.step(now: 103.0)
        engine.press(keyId: 5, now: 103.3)                 // 0.3 s late: too far
        XCTAssertEqual(engine.wrongPresses, 1)
        XCTAssertNil(engine.notes[0].judgment)
        engine.step(now: 103.3)
        XCTAssertEqual(engine.notes[0].judgment, .miss, "and the note is then missed")
    }

    func testWrongKeyIsAWrongPressAndResetsCombo() {
        let engine = makeEngine(.perform)
        engine.press(keyId: 5, now: 103.0)
        XCTAssertEqual(engine.combo, 1)
        engine.press(keyId: 9, now: 104.0)                 // note 1 is key 6
        XCTAssertEqual(engine.wrongPresses, 1)
        XCTAssertEqual(engine.combo, 0)
        XCTAssertEqual(engine.maxCombo, 1)
        XCTAssertNil(engine.notes[1].judgment)
        XCTAssertEqual(engine.recentEvents.last, JudgmentEvent(keyId: 9, judgment: nil, hostTime: 104.0))
    }

    func testPressDuringCountInIsNotHeldAgainstThePlayer() {
        let engine = makeEngine(.perform)
        engine.press(keyId: 9, now: 101.0)
        XCTAssertEqual(engine.wrongPresses, 0)
        XCTAssertTrue(engine.recentEvents.isEmpty)
    }

    func testPressOnlyMatchesNotesInsideTheWindow() {
        // Two consecutive 5s, one second apart.
        let engine = makeEngine(.perform, keys: [5, 5])
        engine.press(keyId: 5, now: 103.45)                // 0.45 s after note 0 and 0.55 s before note 1: neither is in range
        XCTAssertEqual(engine.wrongPresses, 1)
        engine.press(keyId: 5, now: 103.9)                 // 0.1 s before note 1
        XCTAssertNil(engine.notes[0].judgment)
        XCTAssertEqual(engine.notes[1].judgment, .great)
    }

    func testEarliestMatchingNoteWinsWhenTwoAreInTheWindow() {
        // 120 bpm = 0.5 s per beat, so these notes fall at 0, 0.25 and 0.5 s: a press at 0.125 s is inside two windows.
        let chart = SongChart(id: "t", title: "T", bpm: 120,
                              notes: [ChartNote(k: 5, b: 0, d: 0.5), ChartNote(k: 5, b: 0.5, d: 0.5), ChartNote(k: 5, b: 1, d: 0.5)])
        let engine = RhythmEngine(chart: chart, mode: .perform)
        engine.start(now: 0)
        engine.press(keyId: 5, now: engine.countInDuration + 0.125)
        XCTAssertEqual(engine.notes[0].judgment, .great)
        XCTAssertNil(engine.notes[1].judgment)
    }

    func testUntouchedNoteBecomesAMissAfterTheWindow() {
        let engine = makeEngine(.perform)
        engine.step(now: 103.19)
        XCTAssertEqual(engine.counts.miss, 0)
        XCTAssertNil(engine.notes[0].judgment)
        engine.step(now: 103.21)
        XCTAssertEqual(engine.counts.miss, 1)
        XCTAssertEqual(engine.notes[0].judgment, .miss)
        XCTAssertEqual(engine.recentEvents.last, JudgmentEvent(keyId: 5, judgment: .miss, hostTime: 103.21))
    }

    func testMissResetsComboButKeepsPlaying() {
        let engine = makeEngine(.perform)
        engine.press(keyId: 5, now: 103.0)
        engine.step(now: 104.21)                           // note 1 missed
        XCTAssertEqual(engine.combo, 0)
        XCTAssertEqual(engine.maxCombo, 1)
        XCTAssertEqual(engine.phase, .playing)
        engine.press(keyId: 7, now: 105.0)
        XCTAssertEqual(engine.notes[2].judgment, .perfect)
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertEqual(engine.counts, JudgmentCounts(perfect: 2, great: 0, good: 0, miss: 1))
        XCTAssertFalse(engine.isFullCombo)
    }

    func testFinishesAfterTheLastNoteIsHit() {
        let engine = makeEngine(.perform)
        for (index, key) in [5, 6, 7].enumerated() {
            XCTAssertNotEqual(engine.phase, .finished)
            engine.press(keyId: key, now: hostTime(of: index, in: engine))
        }
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertEqual(engine.judgedCount, 3)
        XCTAssertEqual(engine.accuracy, 100)
        XCTAssertEqual(engine.stars(), 3)
        XCTAssertTrue(engine.isFullCombo)
        XCTAssertEqual(engine.maxCombo, 3)
    }

    func testFinishesAfterTheLastNoteIsMissed() {
        let engine = makeEngine(.perform)
        engine.step(now: 105.1)
        XCTAssertEqual(engine.phase, .playing, "the last note can still be hit until 0.2 s after its time")
        engine.step(now: 105.25)
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertEqual(engine.counts.miss, 3)
        XCTAssertEqual(engine.accuracy, 0)
        XCTAssertEqual(engine.stars(), 0)
    }

    func testScoringUsesTheComboMultiplier() {
        let engine = makeEngine(.perform, keys: Array(repeating: 5, count: 31))
        for index in 0..<31 {
            engine.press(keyId: 5, now: hostTime(of: index, in: engine))
        }
        // Notes 1–9 ×1, 10–19 ×2, 20–29 ×3, 30–31 ×4 → 300 × (9 + 20 + 30 + 8)
        XCTAssertEqual(engine.score, 300 * 67)
        XCTAssertEqual(engine.maxCombo, 31)
        XCTAssertEqual(engine.comboMultiplier, 4)
    }

    func testAudioOffsetShiftsTheJudgedTime() {
        let withOffset = makeEngine(.perform, offsetMs: 100)
        withOffset.press(keyId: 5, now: 103.1)
        XCTAssertEqual(withOffset.notes[0].judgment, .perfect)

        let without = makeEngine(.perform)
        without.press(keyId: 5, now: 103.1)
        XCTAssertEqual(without.notes[0].judgment, .great)
    }

    func testRecentEventsKeepOnlyTheLastEight() {
        let engine = makeEngine(.perform)
        engine.step(now: 103.0)
        for i in 0..<10 {
            engine.press(keyId: 30, now: 103.0 + Double(i) * 0.001)
        }
        XCTAssertEqual(engine.wrongPresses, 10)
        XCTAssertEqual(engine.recentEvents.count, 8)
        XCTAssertEqual(engine.recentEvents.last?.hostTime ?? 0, 103.009, accuracy: 1e-9)
    }

    // MARK: Pause / restart

    func testPauseFreezesTheClockAndSuspendsAutoMisses() {
        let engine = makeEngine(.perform)
        engine.step(now: 103.0)
        engine.pause(now: 103.1)
        XCTAssertEqual(engine.phase, .paused)
        engine.step(now: 110)
        engine.press(keyId: 5, now: 110)
        XCTAssertEqual(engine.counts.total, 0, "nothing is judged while paused")
        XCTAssertEqual(engine.songTime(now: 120), 0.1, accuracy: 1e-9)

        engine.resume(now: 120)
        XCTAssertEqual(engine.phase, .playing)
        XCTAssertEqual(engine.songTime(now: 120.1), 0.2, accuracy: 1e-9)
        engine.press(keyId: 5, now: 120.0)                 // song time 0.1 → 0.1 s late
        XCTAssertEqual(engine.notes[0].judgment, .great)
    }

    func testPausingDuringTheCountInResumesIntoTheCountIn() {
        let engine = makeEngine(.perform)
        engine.pause(now: 101)
        engine.resume(now: 200)
        XCTAssertEqual(engine.phase, .countIn)
        XCTAssertEqual(engine.songTime(now: 200), -2, accuracy: 1e-9)
    }

    func testRestartResetsEverything() {
        let engine = makeEngine(.perform)
        engine.press(keyId: 5, now: 103.0)
        engine.press(keyId: 30, now: 103.5)
        engine.restart(now: 500)
        XCTAssertEqual(engine.phase, .countIn)
        XCTAssertEqual(engine.score, 0)
        XCTAssertEqual(engine.combo, 0)
        XCTAssertEqual(engine.maxCombo, 0)
        XCTAssertEqual(engine.wrongPresses, 0)
        XCTAssertEqual(engine.counts, JudgmentCounts())
        XCTAssertTrue(engine.recentEvents.isEmpty)
        XCTAssertTrue(engine.notes.allSatisfy { $0.judgment == nil })
        XCTAssertEqual(engine.songTime(now: 500), -3, accuracy: 1e-9)
        engine.press(keyId: 5, now: 503.0)
        XCTAssertEqual(engine.notes[0].judgment, .perfect)
    }

    // MARK: Practice

    func testPracticeFreezesAtTheNoteAndResumesAfterTheCorrectKey() {
        let engine = makeEngine(.practice)
        engine.step(now: 102.0)
        XCTAssertFalse(engine.isWaiting)
        engine.step(now: 103.5)                            // note 0 reached the line at 103.0
        XCTAssertTrue(engine.isWaiting)
        XCTAssertEqual(engine.songTime(now: 110), 0, accuracy: 1e-9)
        XCTAssertEqual(engine.songTime(now: 150), 0, accuracy: 1e-9, "stays put for as long as it takes")

        engine.press(keyId: 9, now: 150)                   // wrong key
        XCTAssertEqual(engine.wrongPresses, 1)
        XCTAssertNil(engine.notes[0].judgment)
        XCTAssertTrue(engine.isWaiting)

        engine.press(keyId: 5, now: 151)                   // right key
        XCTAssertEqual(engine.notes[0].judgment, .perfect)
        XCTAssertFalse(engine.isWaiting)
        XCTAssertEqual(engine.songTime(now: 151.5), 0.5, accuracy: 1e-9)

        engine.step(now: 152.0)                            // note 1 (time 1) reached
        XCTAssertTrue(engine.isWaiting)
        XCTAssertEqual(engine.songTime(now: 160), 1, accuracy: 1e-9)
        engine.press(keyId: 6, now: 160)
        engine.step(now: 161.0)
        XCTAssertTrue(engine.isWaiting)
        XCTAssertEqual(engine.phase, .playing)
        engine.press(keyId: 7, now: 165)
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertEqual(engine.judgedCount, 3)
    }

    func testPracticeNeverMissesNotes() {
        let engine = makeEngine(.practice)
        engine.step(now: 200)
        XCTAssertEqual(engine.counts.miss, 0)
        XCTAssertTrue(engine.isWaiting)
        XCTAssertEqual(engine.phase, .playing)
    }

    func testPracticeAcceptsAnEarlyCorrectPressWithoutFreezing() {
        let engine = makeEngine(.practice)
        engine.press(keyId: 5, now: 102.9)                 // 0.1 s before the note
        XCTAssertEqual(engine.notes[0].judgment, .perfect)
        XCTAssertFalse(engine.isWaiting)
        engine.step(now: 103.5)
        XCTAssertFalse(engine.isWaiting, "note 1 is still half a second away")
        XCTAssertEqual(engine.songTime(now: 103.5), 0.5, accuracy: 1e-9)
    }

    func testPracticeIgnoresPressesWhileTheNextNoteIsStillFarAway() {
        let engine = makeEngine(.practice)
        engine.press(keyId: 9, now: 101.0)                 // note 0 is 2 s away
        XCTAssertEqual(engine.wrongPresses, 0)
        XCTAssertTrue(engine.recentEvents.isEmpty)
    }

    func testPracticeHintsTheRightKeyAfterTwoWrongPresses() {
        let engine = makeEngine(.practice)
        engine.step(now: 103.0)
        XCTAssertNil(engine.hintKeyId)
        engine.press(keyId: 9, now: 103.5)
        XCTAssertNil(engine.hintKeyId)
        engine.press(keyId: 10, now: 103.6)
        XCTAssertEqual(engine.hintKeyId, 5)
        engine.press(keyId: 5, now: 103.7)
        XCTAssertNil(engine.hintKeyId, "the hint goes away once the note is played")
    }

    func testPracticeHintsTheRightKeyAfterThreeSecondsOfWaiting() {
        let engine = makeEngine(.practice)
        engine.step(now: 103.0)                            // freezes, waiting since 103.0
        engine.step(now: 105.9)
        XCTAssertNil(engine.hintKeyId)
        engine.step(now: 106.0)
        XCTAssertEqual(engine.hintKeyId, 5)
    }

    func testPracticeWaitTimerRestartsAfterAPause() {
        let engine = makeEngine(.practice)
        engine.step(now: 103.0)
        engine.pause(now: 104.0)
        engine.resume(now: 200.0)
        XCTAssertTrue(engine.isWaiting)
        engine.step(now: 201.0)
        XCTAssertNil(engine.hintKeyId, "the pause doesn't count as waiting")
        engine.step(now: 203.0)
        XCTAssertEqual(engine.hintKeyId, 5)
    }

    // MARK: Listen

    func testListenPlaysEachSampleAtItsTimeAndHighlightsTheKey() {
        let log = Recorder()
        let engine = makeEngine(.listen, played: log)
        engine.step(now: 102.9)
        XCTAssertTrue(log.played.isEmpty)
        XCTAssertNil(engine.hintKeyId)

        engine.step(now: 103.0)
        XCTAssertEqual(log.played, ["c2"])
        XCTAssertEqual(engine.hintKeyId, 5)

        engine.step(now: 103.5)
        XCTAssertEqual(engine.hintKeyId, 5)
        engine.step(now: 103.95)                           // past the end of the hint (0.92 s)
        XCTAssertNil(engine.hintKeyId)
        XCTAssertEqual(log.stopped, ["c2"])

        engine.step(now: 104.0)
        XCTAssertEqual(log.played, ["c2", "d2"])
        XCTAssertEqual(engine.hintKeyId, 6)
        XCTAssertEqual(engine.phase, .playing)

        engine.step(now: 105.0)
        XCTAssertEqual(log.played, ["c2", "d2", "e2"])
        engine.step(now: 106.0)                            // last note (time 2, duration 1) is over
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertNil(engine.hintKeyId)
        XCTAssertEqual(engine.counts.miss, 0)
    }

    func testListenIgnoresInputAndNeverScores() {
        let log = Recorder()
        let engine = makeEngine(.listen, played: log)
        engine.step(now: 103.0)
        engine.press(keyId: 5, now: 103.0)
        engine.press(keyId: 9, now: 103.1)
        XCTAssertEqual(engine.score, 0)
        XCTAssertEqual(engine.wrongPresses, 0)
        XCTAssertEqual(engine.combo, 0)
    }

    func testListenSilencesTheSampleWhenPaused() {
        let log = Recorder()
        let engine = makeEngine(.listen, played: log)
        engine.step(now: 103.0)
        engine.pause(now: 103.2)
        XCTAssertEqual(log.stopped, ["c2"])
        XCTAssertNil(engine.hintKeyId)
    }

    func testListenRepeatedKeyRetriggersTheSample() {
        let log = Recorder()
        let engine = makeEngine(.listen, keys: [5, 5], played: log)
        engine.step(now: 103.0)
        engine.step(now: 103.95)
        engine.step(now: 104.0)
        XCTAssertEqual(log.played, ["c2", "c2"])
        XCTAssertEqual(log.stopped, ["c2"], "stopped between the two so the hint visibly retriggers")
    }

    // MARK: Clock

    func testPausableClock() {
        var clock = PausableClock()
        XCTAssertEqual(clock.time(at: 50), 0)
        XCTAssertFalse(clock.isRunning)

        clock.start(at: 100, from: -3)
        XCTAssertTrue(clock.isRunning)
        XCTAssertEqual(clock.time(at: 101.5), -1.5, accuracy: 1e-9)

        clock.pause(at: 102)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.time(at: 500), -1, accuracy: 1e-9)

        clock.resume(at: 600)
        XCTAssertEqual(clock.time(at: 600.5), -0.5, accuracy: 1e-9)
        clock.resume(at: 700)                              // already running: no effect
        XCTAssertEqual(clock.time(at: 601), 0, accuracy: 1e-9)

        clock.freeze(at: 4)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.time(at: 9999), 4)
        clock.resume(at: 1000)
        XCTAssertEqual(clock.time(at: 1001), 5, accuracy: 1e-9)
    }

    func testClockNeverRunsBackwardsFromAStaleTimestamp() {
        var clock = PausableClock()
        clock.freeze(at: 2)
        clock.resume(at: 10.000)
        XCTAssertEqual(clock.time(at: 9.995), 2, "a display-link timestamp just before the resume counts as the resume instant")
    }

    // MARK: Display link

    func testTickerFiresOnTheMainRunLoopAndStops() {
        let fired = expectation(description: "ticked")
        fired.assertForOverFulfill = false
        var ticks = 0
        let ticker = DisplayLinkTicker { _ in
            ticks += 1
            fired.fulfill()
        }
        ticker.start()
        wait(for: [fired], timeout: 5)
        ticker.stop()
        let afterStop = ticks
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(ticks, afterStop, "no ticks after stop()")
    }

    func testAttachAndDetachTickerAreIdempotent() {
        let engine = makeEngine(.listen)
        engine.attachTicker()
        engine.attachTicker()
        engine.detachTicker()
        engine.detachTicker()
    }
}
