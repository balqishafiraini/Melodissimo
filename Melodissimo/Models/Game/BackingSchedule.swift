//
//  BackingSchedule.swift
//  Melodissimo
//

import Foundation

/// Timing maths for playing a backing track in step with the song clock. Pure, so it's unit-tested.
enum BackingSchedule {
    /// The pre-roll may outlast the count-in by at most this much, so a long intro isn't a long wait.
    static let maxExtraLeadIn = 4.0
    /// Drift beyond this is a candidate for correction by seeking (see `DriftGate`). A seek is audible, and an AAC
    /// seek is only accurate to a few tens of milliseconds, so a tight tolerance made it skip and re-seek.
    static let resyncTolerance = 0.12

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

/// Decides when a backing track that has drifted from the song clock is really worth seeking.
///
/// One reading over the tolerance is often a busy moment (a slow frame, a rate change settling), not drift, and
/// every seek is audible. So a seek needs two readings in a row over the tolerance, and at least three seconds
/// since the previous seek. Pure, so it's unit-tested.
struct DriftGate {
    /// Fewest seconds between two seeks.
    static let minimumGap = 3.0

    private var consecutive = 0
    private var lastResync: Double?

    /// `drift` is expected minus actual track position (seconds); `now` any steadily increasing clock.
    mutating func shouldResync(drift: Double, now: Double) -> Bool {
        guard abs(drift) > BackingSchedule.resyncTolerance else {
            consecutive = 0
            return false
        }
        consecutive += 1
        guard consecutive >= 2 else { return false }
        if let lastResync, now - lastResync < Self.minimumGap { return false }
        consecutive = 0
        lastResync = now
        return true
    }

    /// Forget everything: the track was started afresh.
    mutating func reset() {
        consecutive = 0
        lastResync = nil
    }
}
