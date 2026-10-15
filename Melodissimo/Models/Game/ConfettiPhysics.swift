//
//  ConfettiPhysics.swift
//  Melodissimo
//

import Foundation
import CoreGraphics

/// One piece of confetti: how it is thrown and what it looks like. Positions come from `ConfettiPhysics`.
struct ConfettiPiece: Equatable {
    /// Seconds after the burst began that this piece leaves the launcher (the three "repetitions").
    let launchDelay: Double
    /// Throw direction in radians, 0 straight up, positive to the right.
    let angle: Double
    /// Launch speed in points per second (iPad scale).
    let speed: Double
    /// Rotation speed in radians per second.
    let spin: Double
    let startRotation: Double
    /// Which palette colour (an index into the view's list).
    let colorIndex: Int
    let isCircle: Bool
    /// Edge (or diameter) in points (iPad scale).
    let size: Double
}

/// The motion of the result screen's confetti, as plain maths so it can be tested. The view draws what this says.
///
/// Pieces leave the bottom centre of the screen in a ±60° fan, slow down under gravity, tumble, and fade out over
/// the last 0.6 s of their 2.5 s life. Nothing is ever simulated frame to frame: a piece's place is a function of
/// its age, so a skipped frame costs nothing and a test can ask for any moment.
enum ConfettiPhysics {
    static let piecesPerLaunch = 30
    /// Three launches, like the old library's `repetitions: 3`, this far apart.
    static let launches = 3
    static let launchGap = 0.25
    /// How long one piece lives.
    static let life = 2.5
    /// The fade-out at the end of a piece's life.
    static let fadeDuration = 0.6
    static let gravity = 1_100.0
    static let colorCount = 5
    /// Seconds from the trigger until the last piece has faded: the view stops drawing after this.
    static var totalDuration: Double { Double(launches - 1) * launchGap + life }

    /// All the pieces of one burst, the same for the same seed.
    static func pieces(seed: UInt64) -> [ConfettiPiece] {
        var random = SeededRandom(seed: seed)
        var pieces: [ConfettiPiece] = []
        for launch in 0..<launches {
            for _ in 0..<piecesPerLaunch {
                pieces.append(ConfettiPiece(
                    launchDelay: Double(launch) * launchGap,
                    angle: Double.random(in: -(Double.pi / 3)...(Double.pi / 3), using: &random),
                    speed: Double.random(in: 650...1_150, using: &random),
                    spin: Double.random(in: -9...9, using: &random),
                    startRotation: Double.random(in: 0...(2 * Double.pi), using: &random),
                    colorIndex: Int.random(in: 0..<colorCount, using: &random),
                    isCircle: Bool.random(using: &random),
                    size: Double.random(in: 10...18, using: &random)))
            }
        }
        return pieces
    }

    /// Where the piece is, relative to the launch point (x right, y down), `age` seconds after it left.
    static func position(of piece: ConfettiPiece, at age: Double) -> CGPoint {
        let vx = piece.speed * sin(piece.angle)
        let vy = -piece.speed * cos(piece.angle)
        return CGPoint(x: vx * age, y: vy * age + 0.5 * gravity * age * age)
    }

    /// The piece's rotation in radians at `age`.
    static func rotation(of piece: ConfettiPiece, at age: Double) -> Double {
        piece.startRotation + piece.spin * age
    }

    /// 1 while the piece is in full colour, falling to 0 over the last `fadeDuration`; 0 before launch and after death.
    static func opacity(at age: Double) -> Double {
        guard age >= 0, age < life else { return 0 }
        return min(1, (life - age) / fadeDuration)
    }
}
