//
//  BackingSchedule.swift
//  Melodissimo
//

import Foundation

/// Timing maths for playing a backing track in step with the song clock. Pure, so it's unit-tested.
enum BackingSchedule {
    /// The pre-roll may outlast the count-in by at most this much, so a long intro isn't a long wait.
    static let maxExtraLeadIn = 4.0
    /// Drift beyond this is corrected by seeking.
    static let resyncTolerance = 0.05

    /// How long the song clock runs before beat 0 when a backing track plays (wall seconds).
    static func leadIn(offset: Double, speed: Double, countIn: Double) -> Double {
        max(countIn, min(offset / speed, countIn + maxExtraLeadIn))
    }

    /// Where to start the track and how long to wait from `hostTime`, so the sound *heard*
    /// at `hostTime` belongs to `songTime` (output latency is sent ahead).
    static func start(songTime: Double, speed: Double, offset: Double, outputLatency: Double) -> (position: Double, delay: Double) {
        let position = offset + songTime * speed + outputLatency * speed
        return position >= 0 ? (position, 0) : (0, -position / speed)
    }

    static func needsResync(expected: Double, actual: Double) -> Bool {
        abs(expected - actual) > resyncTolerance
    }
}
