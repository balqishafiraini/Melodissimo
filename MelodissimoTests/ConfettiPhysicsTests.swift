import XCTest
@testable import Melodissimo

final class ConfettiPhysicsTests: XCTestCase {

    func testTheSameSeedGivesTheSameBurst() {
        XCTAssertEqual(ConfettiPhysics.pieces(seed: 3), ConfettiPhysics.pieces(seed: 3))
        XCTAssertNotEqual(ConfettiPhysics.pieces(seed: 3), ConfettiPhysics.pieces(seed: 4))
    }

    func testThreeLaunchesOfThirtyPiecesInAFan() {
        let pieces = ConfettiPhysics.pieces(seed: 1)
        XCTAssertEqual(pieces.count, 90)
        XCTAssertEqual(Set(pieces.map(\.launchDelay)), [0, 0.25, 0.5])
        for piece in pieces {
            XCTAssertLessThanOrEqual(abs(piece.angle), Double.pi / 3 + 1e-9, "inside the ±60° fan")
            XCTAssertTrue((0..<ConfettiPhysics.colorCount).contains(piece.colorIndex))
        }
    }

    func testPiecesRiseFirstThenFallUnderGravity() {
        for piece in ConfettiPhysics.pieces(seed: 5) {
            let early = ConfettiPhysics.position(of: piece, at: 0.1)
            XCTAssertLessThan(early.y, 0, "thrown upward")
            let apexAge = piece.speed * cos(piece.angle) / ConfettiPhysics.gravity
            XCTAssertGreaterThan(ConfettiPhysics.position(of: piece, at: apexAge + 0.5).y,
                                 ConfettiPhysics.position(of: piece, at: apexAge).y, "falling after the apex")
        }
    }

    func testAPieceIsFullyFadedAtTheEndOfItsLife() {
        XCTAssertEqual(ConfettiPhysics.opacity(at: ConfettiPhysics.life), 0)
        XCTAssertEqual(ConfettiPhysics.opacity(at: 0), 1)
        XCTAssertEqual(ConfettiPhysics.opacity(at: ConfettiPhysics.life - ConfettiPhysics.fadeDuration), 1, accuracy: 1e-9)
        XCTAssertEqual(ConfettiPhysics.opacity(at: ConfettiPhysics.life - ConfettiPhysics.fadeDuration / 2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(ConfettiPhysics.opacity(at: -0.1), 0, "not launched yet")
        XCTAssertEqual(ConfettiPhysics.opacity(at: 3), 0)
    }

    func testEveryPieceHasLeftTheScreenOrFadedByTheEndOfItsLife() {
        // The launch point is the bottom centre of an iPad-sized screen (820 pt tall, 1180 wide).
        for piece in ConfettiPhysics.pieces(seed: 2) {
            let place = ConfettiPhysics.position(of: piece, at: ConfettiPhysics.life)
            let x = 590 + place.x, y = 820 + place.y
            let onScreen = (0...1180).contains(x) && (0...820).contains(y)
            XCTAssertTrue(!onScreen || ConfettiPhysics.opacity(at: ConfettiPhysics.life) == 0)
        }
    }

    func testTheBurstEndsWhenTheLastLaunchedPieceFades() {
        XCTAssertEqual(ConfettiPhysics.totalDuration, 0.5 + 2.5, accuracy: 1e-9)
    }
}
