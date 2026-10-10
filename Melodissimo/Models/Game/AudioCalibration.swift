//
//  AudioCalibration.swift
//  Melodissimo
//

import Foundation

/// The maths behind the "Tap to the beat" calibration: eight metronome beats, the player taps along,
/// and the average lateness of the taps is suggested as the audio offset.
///
/// The offset has the engine's sign: a positive value means the player's taps arrive late (screen and
/// speaker lag behind the song clock), so the engine judges a press against `songTime − offset`.
enum AudioCalibration {
    static let beatCount = 8
    /// Seconds between beats (80 bpm: slow enough for a child to tap along calmly).
    static let beatInterval = 0.75
    /// Seconds from pressing Start to the first beat.
    static let leadIn = 1.5
    /// A tap further than this from every beat is a stray touch and is ignored.
    static let tolerance = 0.3
    /// Fewer usable taps than this give no suggestion.
    static let minimumTaps = 4
    static let offsetRange: ClosedRange<Int> = -150...150

    /// Host times of the beats of a run that starts at `start`.
    static func beatTimes(start: Double) -> [Double] {
        (0..<beatCount).map { start + leadIn + Double($0) * beatInterval }
    }

    /// How late (+) or early (−) each usable tap was against the closest beat, in seconds.
    static func tapOffsets(beats: [Double], taps: [Double]) -> [Double] {
        guard !beats.isEmpty else { return [] }
        return taps.compactMap { tap in
            guard let nearest = beats.min(by: { abs($0 - tap) < abs($1 - tap) }) else { return nil }
            let offset = tap - nearest
            return abs(offset) <= tolerance ? offset : nil
        }
    }

    /// The average tap offset in milliseconds, clamped to the setting's range. `nil` when there were
    /// too few usable taps to say anything.
    static func suggestedOffsetMs(beats: [Double], taps: [Double]) -> Int? {
        let offsets = tapOffsets(beats: beats, taps: taps)
        guard offsets.count >= minimumTaps else { return nil }
        let averageMs = offsets.reduce(0, +) / Double(offsets.count) * 1000
        return min(max(Int(averageMs.rounded()), offsetRange.lowerBound), offsetRange.upperBound)
    }
}
