//
//  CalibrationViewModel.swift
//  Melodissimo
//

import Foundation

/// Runs the "Tap to the beat" calibration: eight metronome beats, the player's taps, then a suggested
/// audio offset. Time is injected (`now` host seconds), so tests can drive it without a display link.
final class CalibrationViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case running
        case finished
    }

    @Published private(set) var phase: Phase = .idle
    /// How many beats have sounded so far (0...8), for the dots and the flash.
    @Published private(set) var beatsPlayed = 0
    /// The suggested offset once finished, or `nil` when too few taps were usable.
    @Published private(set) var suggestion: Int?

    private(set) var beats: [Double] = []
    private(set) var taps: [Double] = []

    /// Called as each beat is due, with the beat's index. The view plays the click here.
    var onBeat: (Int) -> Void = { _ in }

    /// Seconds after the last beat before the run closes, so a late final tap still counts.
    static let tail = 0.6

    func start(now: Double) {
        beats = AudioCalibration.beatTimes(start: now)
        taps = []
        beatsPlayed = 0
        suggestion = nil
        phase = .running
    }

    /// A tap during the run. Taps before the run or after it are ignored.
    func tap(now: Double) {
        guard phase == .running else { return }
        taps.append(now)
    }

    /// Fires the beats that are due and closes the run after the tail.
    func step(now: Double) {
        guard phase == .running else { return }
        while beatsPlayed < beats.count, now >= beats[beatsPlayed] {
            onBeat(beatsPlayed)
            beatsPlayed += 1
        }
        if let last = beats.last, now >= last + Self.tail {
            suggestion = AudioCalibration.suggestedOffsetMs(beats: beats, taps: taps)
            phase = .finished
        }
    }

    func reset() {
        phase = .idle
        beatsPlayed = 0
        suggestion = nil
        beats = []
        taps = []
    }
}
