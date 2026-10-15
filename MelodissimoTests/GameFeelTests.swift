import XCTest
@testable import Melodissimo

final class HitBurstTests: XCTestCase {

    func testABurstHasSixToTenParticles() {
        for seed in -20...200 {
            let count = HitBurst.particleCount(seed: seed)
            XCTAssertTrue((6...10).contains(count), "seed \(seed) gave \(count)")
            XCTAssertEqual(HitBurst.particles(progress: 0.5, seed: seed).count, count)
        }
    }

    func testTheSeedPicksTheCountSoBurstsDiffer() {
        let counts = Set((0..<20).map { HitBurst.particleCount(seed: $0) })
        XCTAssertEqual(counts, [6, 7, 8, 9, 10])
    }

    func testParticlesStartNearTheHitAndFanOutUpward() {
        let start = HitBurst.particles(progress: 0, seed: 3)
        let end = HitBurst.particles(progress: 0.9, seed: 3)
        for (first, last) in zip(start, end) {
            XCTAssertLessThan(first.dy, 0, "every particle goes up from the hit line")
            XCTAssertLessThan(last.dy, 0)
            XCTAssertGreaterThan(hypot(last.dx, last.dy), hypot(first.dx, first.dy), "they travel outward")
        }
    }

    func testParticlesSpreadSidewaysBothWays() {
        let particles = HitBurst.particles(progress: 1, seed: 0)
        XCTAssertTrue(particles.contains { $0.dx < 0 })
        XCTAssertTrue(particles.contains { $0.dx > 0 })
    }

    func testParticlesShrinkAndFadeToNothing() {
        let early = HitBurst.particles(progress: 0.1, seed: 5)[0]
        let late = HitBurst.particles(progress: 0.9, seed: 5)[0]
        XCTAssertGreaterThan(early.radius, late.radius)
        XCTAssertGreaterThan(early.opacity, late.opacity)
        XCTAssertEqual(HitBurst.particles(progress: 1, seed: 5).map(\.opacity), Array(repeating: 0, count: HitBurst.particleCount(seed: 5)))
    }

    func testProgressIsClamped() {
        XCTAssertEqual(HitBurst.particles(progress: -1, seed: 2), HitBurst.particles(progress: 0, seed: 2))
        XCTAssertEqual(HitBurst.particles(progress: 7, seed: 2), HitBurst.particles(progress: 1, seed: 2))
    }

    func testTheBurstIsThreeTenthsOfASecond() {
        XCTAssertEqual(HitBurst.duration, 0.3)
    }
}

final class LaneFlashesTests: XCTestCase {

    func testAPressFlashesItsLaneAndFadesOut() {
        let flashes = LaneFlashes()
        flashes.press(keyId: 9, at: 10)
        XCTAssertEqual(flashes.active(at: 10).first?.keyId, 9)
        XCTAssertEqual(flashes.active(at: 10).first?.progress ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(flashes.active(at: 10 + LaneFlashes.duration / 2).first?.progress ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertTrue(flashes.active(at: 10 + LaneFlashes.duration).isEmpty)
    }

    func testSeveralLanesFlashAtOnceAndAPressRestartsItsLane() {
        let flashes = LaneFlashes()
        flashes.press(keyId: 5, at: 1)
        flashes.press(keyId: 7, at: 1.1)
        XCTAssertEqual(Set(flashes.active(at: 1.15).map(\.keyId)), [5, 7])
        flashes.press(keyId: 5, at: 1.2)
        let again = flashes.active(at: 1.2).first { $0.keyId == 5 }
        XCTAssertEqual(again?.progress ?? -1, 0, accuracy: 1e-9)
    }

    func testNothingFlashesBeforeThePress() {
        let flashes = LaneFlashes()
        flashes.press(keyId: 1, at: 5)
        XCTAssertTrue(flashes.active(at: 4).isEmpty)
    }

    func testTheTableStaysSmallAndClearEmptiesIt() {
        let flashes = LaneFlashes()
        for index in 0..<200 {
            flashes.press(keyId: index, at: Double(index))   // each far apart in time
        }
        XCTAssertLessThanOrEqual(flashes.active(at: 199.1).count, 1)
        flashes.press(keyId: 3, at: 300)
        flashes.clear()
        XCTAssertTrue(flashes.active(at: 300).isEmpty)
    }
}

final class HitSparkleTests: XCTestCase {

    func testTwinklesStayNearTheNoteAndFadeInAndOut() {
        for time in stride(from: -1.0, through: 3.0, by: 0.07) {
            let twinkles = HitSparkle.twinkles(time: time, seed: 12)
            XCTAssertEqual(twinkles.count, HitSparkle.count)
            for twinkle in twinkles {
                XCTAssertLessThanOrEqual(abs(twinkle.dx), 0.6)
                XCTAssertLessThan(twinkle.dy, 0, "twinkles rise off the line")
                XCTAssertTrue((0...1).contains(twinkle.opacity))
                XCTAssertGreaterThanOrEqual(twinkle.size, 3)
            }
        }
    }

    func testTheSameMomentDrawsTheSameTwinkles() {
        XCTAssertEqual(HitSparkle.twinkles(time: 1.234, seed: 4), HitSparkle.twinkles(time: 1.234, seed: 4))
    }

    func testATwinkleMovesWhenItIsReborn() {
        let first = HitSparkle.twinkles(time: 0.1, seed: 4)[0]
        let next = HitSparkle.twinkles(time: 0.1 + HitSparkle.lifetime, seed: 4)[0]
        XCTAssertNotEqual(first.dx, next.dx)
    }
}

final class ComboPulseTests: XCTestCase {

    func testItPulsesOnEveryTenthHit() {
        XCTAssertEqual((0...45).filter(ComboPulse.isMilestone), [10, 20, 30, 40])
        XCTAssertFalse(ComboPulse.isMilestone(0), "a reset to zero is not a milestone")
    }
}
