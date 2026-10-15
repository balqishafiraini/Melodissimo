import XCTest
@testable import Melodissimo

final class BackingScheduleTests: XCTestCase {

    func testLeadInIsTheCountInForAShortIntro() {
        XCTAssertEqual(BackingSchedule.leadIn(offset: 1, speed: 1, countIn: 2), 2, accuracy: 1e-9)
        XCTAssertEqual(BackingSchedule.leadIn(offset: 0, speed: 1, countIn: 2), 2, accuracy: 1e-9)
    }

    func testLeadInFollowsALongIntroUpToTheCap() {
        XCTAssertEqual(BackingSchedule.leadIn(offset: 4, speed: 1, countIn: 2), 4, accuracy: 1e-9)
        // 20 s intro: count-in + 4
        XCTAssertEqual(BackingSchedule.leadIn(offset: 20, speed: 1, countIn: 2), 6, accuracy: 1e-9)
        // Slower playback stretches the intro: 6 s at 0.5× is 12 s of wall time, capped at 2 + 4.
        XCTAssertEqual(BackingSchedule.leadIn(offset: 6, speed: 0.5, countIn: 2), 6, accuracy: 1e-9)
        XCTAssertEqual(BackingSchedule.leadIn(offset: 2.5, speed: 0.5, countIn: 2), 5, accuracy: 1e-9)
    }

    func testStartWithAPositivePosition() {
        let s = BackingSchedule.start(songTime: -3, speed: 1, offset: 5, outputLatency: 0)
        XCTAssertEqual(s.position, 2, accuracy: 1e-9)
        XCTAssertEqual(s.delay, 0, accuracy: 1e-9)
    }

    func testStartWithANegativePositionWaitsInsteadOfSeeking() {
        // The clock is 6 s before beat 0 but the track only has 2 s of intro: wait 4 s.
        let s = BackingSchedule.start(songTime: -6, speed: 1, offset: 2, outputLatency: 0)
        XCTAssertEqual(s.position, 0, accuracy: 1e-9)
        XCTAssertEqual(s.delay, 4, accuracy: 1e-9)
        // At 0.5× the same 4 track-seconds take 8 wall seconds.
        let slow = BackingSchedule.start(songTime: -6, speed: 0.5, offset: 2, outputLatency: 0)
        XCTAssertEqual(slow.delay, 2, accuracy: 1e-9)   // position = 2 - 3 = -1 → wait 1 / 0.5
    }

    func testOutputLatencyIsSentAhead() {
        let s = BackingSchedule.start(songTime: 0, speed: 0.5, offset: 10, outputLatency: 0.04)
        XCTAssertEqual(s.position, 10.02, accuracy: 1e-9)
    }

    func testNeedsResync() {
        XCTAssertFalse(BackingSchedule.needsResync(expected: 10, actual: 10.1))
        XCTAssertTrue(BackingSchedule.needsResync(expected: 10, actual: 10.13))
        XCTAssertTrue(BackingSchedule.needsResync(expected: 10, actual: 9.85))
    }

    func testDriftGateNeedsTwoReadingsInARowOverTheTolerance() {
        var gate = DriftGate()
        XCTAssertFalse(gate.shouldResync(drift: 0.2, now: 10), "one reading is just a busy moment")
        XCTAssertTrue(gate.shouldResync(drift: 0.2, now: 11))
    }

    func testDriftGateForgetsAReadingThatWasBackInTolerance() {
        var gate = DriftGate()
        XCTAssertFalse(gate.shouldResync(drift: 0.3, now: 10))
        XCTAssertFalse(gate.shouldResync(drift: 0.02, now: 11), "recovered by itself")
        XCTAssertFalse(gate.shouldResync(drift: -0.3, now: 12), "the count starts over, in either direction")
        XCTAssertTrue(gate.shouldResync(drift: -0.3, now: 13))
    }

    func testDriftGateWaitsThreeSecondsBetweenSeeks() {
        var gate = DriftGate()
        _ = gate.shouldResync(drift: 0.5, now: 10)
        XCTAssertTrue(gate.shouldResync(drift: 0.5, now: 11))                  // seek at t = 11
        XCTAssertFalse(gate.shouldResync(drift: 0.5, now: 12))
        XCTAssertFalse(gate.shouldResync(drift: 0.5, now: 13), "two seconds after the seek: too soon")
        XCTAssertTrue(gate.shouldResync(drift: 0.5, now: 14.1), "three seconds have passed and it is still off")
    }

    func testDriftGateResetForgetsThePreviousSeek() {
        var gate = DriftGate()
        _ = gate.shouldResync(drift: 0.5, now: 10)
        XCTAssertTrue(gate.shouldResync(drift: 0.5, now: 11))
        gate.reset()
        _ = gate.shouldResync(drift: 0.5, now: 11.5)
        XCTAssertTrue(gate.shouldResync(drift: 0.5, now: 12), "a fresh start has no seek on record")
    }
}
