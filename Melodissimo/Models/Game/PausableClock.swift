//
//  PausableClock.swift
//  Melodissimo
//

import Foundation
import QuartzCore

/// A song clock driven by the host clock (`CACurrentMediaTime()`) that can be paused,
/// frozen at an exact song time (practice "wait" mode) and resumed. Every method takes
/// the host time explicitly so tests can drive it with fake values.
struct PausableClock {
    /// Song-seconds accumulated while paused or frozen.
    private(set) var banked: Double = 0
    /// Host time of the last start/resume; `nil` while paused or frozen.
    private var runningSince: CFTimeInterval?

    var isRunning: Bool { runningSince != nil }

    /// Song time at the given host time. Never runs backwards: a host time slightly
    /// before the last resume (display-link timestamps trail touch timestamps) counts as the resume instant.
    func time(at now: CFTimeInterval) -> Double {
        guard let runningSince else { return banked }
        return banked + max(0, now - runningSince)
    }

    /// Starts running from song time `t`.
    mutating func start(at now: CFTimeInterval, from t: Double) {
        banked = t
        runningSince = now
    }

    mutating func pause(at now: CFTimeInterval) {
        banked = time(at: now)
        runningSince = nil
    }

    /// Stops at exactly song time `t` (practice wait).
    mutating func freeze(at t: Double) {
        banked = t
        runningSince = nil
    }

    mutating func resume(at now: CFTimeInterval) {
        if runningSince == nil { runningSince = now }
    }
}
