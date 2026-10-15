//
//  PitchDetector.swift
//  Melodissimo
//

import Foundation
import Accelerate

/// YIN pitch detection (de Cheveigné & Kawahara, 2002) limited to the pianika's range.
///
/// The difference function is the cost: for every lag τ up to ~290 it sums the squared difference of ~1750 sample
/// pairs, about half a million multiply-adds per analysed hop, ~47 hops a second. It runs on Accelerate
/// (`vDSP_distancesq`, one call per lag, no allocation); the maths is exactly the textbook algorithm's, only
/// faster, which matters most in a Debug build on a phone where the scalar loop could fall behind the microphone.
enum PitchDetector {
    /// Lowest and highest frequency worth looking for (F3 is 174.6 Hz, C6 is 1046.5 Hz).
    static let frequencyRange: ClosedRange<Double> = 165...1100
    static let threshold: Float = 0.15

    /// Scratch memory for `detect`, so a long-lived caller (the microphone) allocates it once instead of per hop.
    final class Workspace {
        fileprivate var normalized: [Float] = []
        init() {}
    }

    /// The fundamental frequency of `samples` in Hz, or `nil` when there is no clear pitch.
    /// Needs at least `window + sampleRate / 165` samples; 2048 at 44.1 kHz or 48 kHz is plenty.
    static func detect(samples: [Float], sampleRate: Double, workspace: Workspace = Workspace()) -> Double? {
        samples.withUnsafeBufferPointer { detect(samples: $0, sampleRate: sampleRate, workspace: workspace) }
    }

    /// The same, for samples already in memory (a slice of the microphone window), without copying them.
    static func detect(samples buffer: UnsafeBufferPointer<Float>, sampleRate: Double, workspace: Workspace) -> Double? {
        let tauMin = max(2, Int(sampleRate / frequencyRange.upperBound))
        let tauMax = Int(sampleRate / frequencyRange.lowerBound)
        let window = buffer.count - tauMax
        guard window >= tauMax, tauMin < tauMax, let base = buffer.baseAddress else { return nil }

        // Difference function, then the cumulative mean normalised difference.
        if workspace.normalized.count != tauMax + 1 {
            workspace.normalized = [Float](repeating: 1, count: tauMax + 1)
        }
        var runningSum: Float = 0
        workspace.normalized.withUnsafeMutableBufferPointer { normalized in
            normalized[0] = 1
            for tau in 1...tauMax {
                var difference: Float = 0
                vDSP_distancesq(base, 1, base + tau, 1, &difference, vDSP_Length(window))
                runningSum += difference
                normalized[tau] = runningSum > 0 ? difference * Float(tau) / runningSum : 1
            }
        }
        let normalized = workspace.normalized

        // First dip below the threshold, followed down to its local minimum.
        var tau = tauMin
        while tau < tauMax {
            if normalized[tau] < threshold {
                while tau + 1 < tauMax, normalized[tau + 1] < normalized[tau] { tau += 1 }
                return sampleRate / refinedTau(tau, in: normalized)
            }
            tau += 1
        }
        return nil
    }

/// Parabolic interpolation around the minimum for sub-sample accuracy.
    private static func refinedTau(_ tau: Int, in values: [Float]) -> Double {
        guard tau > 1, tau + 1 < values.count else { return Double(tau) }
        let before = Double(values[tau - 1]), here = Double(values[tau]), after = Double(values[tau + 1])
        let denominator = before - 2 * here + after
        guard abs(denominator) > 1e-12 else { return Double(tau) }
        return Double(tau) + (before - after) / (2 * denominator)
    }

    /// Root-mean-square level of `samples` (0…1 for full-scale audio).
    static func rms(of samples: [Float]) -> Float {
        samples.withUnsafeBufferPointer { rms(of: $0) }
    }

    static func rms(of samples: UnsafeBufferPointer<Float>) -> Float {
        guard let base = samples.baseAddress, !samples.isEmpty else { return 0 }
        var result: Float = 0
        vDSP_rmsqv(base, 1, &result, vDSP_Length(samples.count))
        return result
    }
}

/// Turns a frequency into a pianika key.
enum PitchMapper {
    private static let keyIdBySemitone: [Int: Int] = Dictionary(uniqueKeysWithValues: NoteCatalog.all.map { ($0.semitone, $0.id) })

    /// MIDI note number of F3, the lowest key (`semitone` 0).
    static let lowestMidi = 53

    /// The key whose pitch is nearest `frequency`, or `nil` outside F3…C6.
    static func keyId(forFrequency frequency: Double) -> Int? {
        guard frequency > 0 else { return nil }
        let midi = Int((69 + 12 * log2(frequency / 440)).rounded())
        return keyIdBySemitone[midi - lowestMidi]
    }
}

/// Decides when a stream of analysed frames contains a new note: the level must be above the
/// noise gate and the same key must be heard in two frames in a row. The next onset needs a
/// different key, or silence in between, so one long note is never reported twice.
struct OnsetDetector {
    var noiseGate: Float = 0.01
    var requiredFrames = 2

    private var candidate: Int?
    private var candidateCount = 0
    private var candidateStart: Double = 0
    private var lastEmitted: Int?

    init(noiseGate: Float = 0.01, requiredFrames: Int = 2) {
        self.noiseGate = noiseGate
        self.requiredFrames = requiredFrames
    }

    /// Feeds one frame (`time` is when the frame began). Returns the key and the time of its
    /// first frame when a new note has just been confirmed.
    mutating func process(rms: Float, keyId: Int?, time: Double) -> (keyId: Int, time: Double)? {
        guard rms >= noiseGate, let keyId else {
            candidate = nil
            candidateCount = 0
            lastEmitted = nil
            return nil
        }
        if keyId == candidate {
            candidateCount += 1
        } else {
            candidate = keyId
            candidateCount = 1
            candidateStart = time
        }
        guard candidateCount == requiredFrames, keyId != lastEmitted else { return nil }
        lastEmitted = keyId
        return (keyId, candidateStart)
    }

    mutating func reset() {
        candidate = nil
        candidateCount = 0
        lastEmitted = nil
    }
}
