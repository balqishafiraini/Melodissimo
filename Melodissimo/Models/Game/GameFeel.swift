//
//  GameFeel.swift
//  Melodissimo
//

import Foundation
import QuartzCore

/// The little burst of circles at the hit line on a Perfect. Pure maths, so the highway only has to
/// draw what this returns.
enum HitBurst {
    /// Seconds the burst lasts.
    static let duration = 0.3

    struct Particle: Equatable {
        /// Offset from the centre of the hit, in points (negative `dy` is up).
        let dx: Double
        let dy: Double
        let radius: Double
        let opacity: Double
    }

    /// 6 to 10 particles, chosen by the seed so bursts differ a little from each other.
    static func particleCount(seed: Int) -> Int {
        6 + abs(seed) % 5
    }

    /// The particles `progress` (0...1) of the way through the burst. They fan out over the upper half
    /// circle, slow down as they go, shrink and fade; at 1 nothing is left to see.
    static func particles(progress: Double, seed: Int) -> [Particle] {
        let p = min(max(progress, 0), 1)
        let count = particleCount(seed: seed)
        let eased = 1 - (1 - p) * (1 - p)
        return (0..<count).map { index in
            // Spread over the top half; the seed nudges the whole fan and each particle's reach.
            let slot = (Double(index) + 0.5) / Double(count)
            let angle = -Double.pi + slot * Double.pi + Double(abs(seed) % 7) * 0.02
            let reach = 0.7 + 0.3 * (Double((index * 37 + abs(seed)) % 10) / 9)
            let distance = 10 + 48 * reach * eased
            return Particle(dx: cos(angle) * distance,
                            dy: sin(angle) * distance,
                            radius: 1 + 5 * (1 - p),
                            opacity: 1 - p)
        }
    }
}

/// The twinkles thrown off where a hit note slides through the hit line. Pure maths, like `HitBurst`.
enum HitSparkle {
    /// Twinkles alive at once on one note.
    static let count = 5
    /// Seconds one twinkle lives, rising off the line and fading.
    static let lifetime = 0.45

    struct Twinkle: Equatable {
        /// Sideways offset from the note's centre, as a fraction of the glow's width.
        let dx: Double
        /// Offset from the hit line in points (negative is up).
        let dy: Double
        /// Radius of the star in points.
        let size: Double
        let opacity: Double
    }

    /// The twinkles at song time `time`. Each one lives `lifetime`, staggered so they don't all blink together,
    /// and jumps to a new spot every time it is reborn; `seed` (the note) keeps neighbouring notes from matching.
    static func twinkles(time: Double, seed: Int) -> [Twinkle] {
        (0..<count).map { index in
            let clock = time / lifetime + Double(index) / Double(count)
            let cycle = Int(clock.rounded(.down))
            let progress = clock - Double(cycle)
            let hash = abs((seed &* 31 &+ index &* 17 &+ cycle &* 53) % 101)
            let fade = sin(progress * .pi)
            return Twinkle(dx: (Double(hash) / 100 - 0.5) * 1.2,
                           dy: -4 - 30 * progress,
                           size: 3 + 6 * fade,
                           opacity: fade)
        }
    }
}

/// When each key was last pressed, so the highway can flash that key's lane for a moment. A plain
/// class that is read every frame and never published, like the engine's notes.
final class LaneFlashes {
    /// Seconds a lane flash fades over.
    static let duration = 0.25

    private var presses: [Int: CFTimeInterval] = [:]

    func press(keyId: Int, at time: CFTimeInterval) {
        presses[keyId] = time
        // Forget the old ones now and then, so the table stays at most one entry per key.
        if presses.count > 40 {
            presses = presses.filter { time - $0.value < Self.duration }
        }
    }

    /// The lanes still flashing at `now`, with how far through the fade each is (0 = just pressed).
    func active(at now: CFTimeInterval) -> [(keyId: Int, progress: Double)] {
        presses.compactMap { keyId, time in
            let age = now - time
            guard age >= 0, age < Self.duration else { return nil }
            return (keyId, age / Self.duration)
        }
    }

    func clear() {
        presses.removeAll()
    }
}

enum ComboPulse {
    /// The combo text pulses on every tenth hit, which is also when the multiplier steps up.
    static func isMilestone(_ combo: Int) -> Bool {
        combo > 0 && combo % 10 == 0
    }
}
