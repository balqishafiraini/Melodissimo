import XCTest
@testable import Melodissimo

final class PitchDetectorTests: XCTestCase {

    private func sine(_ frequency: Double, sampleRate: Double = 44100, count: Int = 2048, amplitude: Float = 0.5) -> [Float] {
        (0..<count).map { amplitude * Float(sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
    }

    /// F3, C4 (middle C is 261.63), A4, E5 and C6, the extremes and the middle of the keyboard.
    func testDetectsFiveFrequenciesWithinASemitone() throws {
        for frequency in [174.61, 261.63, 440.0, 659.26, 1046.5] {
            let detected = try XCTUnwrap(PitchDetector.detect(samples: sine(frequency), sampleRate: 44100), "\(frequency) Hz")
            XCTAssertEqual(12 * log2(detected / frequency), 0, accuracy: 1, "\(frequency) Hz read as \(detected)")
        }
    }

    func testDetectsAt48kHz() throws {
        let detected = try XCTUnwrap(PitchDetector.detect(samples: sine(440, sampleRate: 48000), sampleRate: 48000))
        XCTAssertEqual(detected, 440, accuracy: 3)
    }

    func testSilenceAndNoiseHaveNoPitch() {
        XCTAssertNil(PitchDetector.detect(samples: [Float](repeating: 0, count: 2048), sampleRate: 44100))
        var generator = SeededRandom(seed: 7)
        let noise = (0..<2048).map { _ in Float(Double.random(in: -0.5...0.5, using: &generator)) }
        XCTAssertNil(PitchDetector.detect(samples: noise, sampleRate: 44100))
    }

    func testRmsOfASineIsAmplitudeOverRootTwo() {
        XCTAssertEqual(PitchDetector.rms(of: sine(440, amplitude: 1)), 0.7071, accuracy: 0.01)
        XCTAssertEqual(PitchDetector.rms(of: []), 0)
    }

    func testFrequencyMapsToTheRightKey() {
        XCTAssertEqual(PitchMapper.keyId(forFrequency: 174.61), 1)    // F3 = 4.
        XCTAssertEqual(PitchMapper.keyId(forFrequency: 261.63), 5)    // C4 = 1
        XCTAssertEqual(PitchMapper.keyId(forFrequency: 277.18), 23)   // C#4 = 1#
        XCTAssertEqual(PitchMapper.keyId(forFrequency: 1046.5), 19)   // C6 = 1˙˙
        XCTAssertNil(PitchMapper.keyId(forFrequency: 100))
        XCTAssertNil(PitchMapper.keyId(forFrequency: 2000))
        XCTAssertNil(PitchMapper.keyId(forFrequency: 0))
    }

    func testTheLowestKeyHasMidiFiftyThree() {
        XCTAssertEqual(PitchMapper.lowestMidi + NoteCatalog.note(1).semitone, 53)
    }

    // MARK: Onset

    func testOnsetNeedsTwoFramesOfTheSameKeyAndReportsTheFirstFramesTime() {
        var detector = OnsetDetector()
        XCTAssertNil(detector.process(rms: 0.1, keyId: 5, time: 1.0))
        let onset = detector.process(rms: 0.1, keyId: 5, time: 1.02)
        XCTAssertEqual(onset?.keyId, 5)
        XCTAssertEqual(onset?.time ?? 0, 1.0, accuracy: 1e-9)
    }

    func testAHeldNoteIsReportedOnce() {
        var detector = OnsetDetector()
        var onsets = 0
        for frame in 0..<20 where detector.process(rms: 0.1, keyId: 5, time: Double(frame) * 0.02) != nil { onsets += 1 }
        XCTAssertEqual(onsets, 1)
    }

    func testAChangeOfPitchIsANewOnset() {
        var detector = OnsetDetector()
        for frame in 0..<4 { _ = detector.process(rms: 0.1, keyId: 5, time: Double(frame) * 0.02) }
        _ = detector.process(rms: 0.1, keyId: 6, time: 0.1)
        XCTAssertEqual(detector.process(rms: 0.1, keyId: 6, time: 0.12)?.keyId, 6)
    }

    func testSilenceBetweenTwoNotesOfTheSameKeyMakesTwoOnsets() {
        var detector = OnsetDetector()
        var onsets = 0
        for frame in 0..<4 where detector.process(rms: 0.1, keyId: 5, time: Double(frame) * 0.02) != nil { onsets += 1 }
        _ = detector.process(rms: 0.0, keyId: nil, time: 0.1)
        for frame in 5..<9 where detector.process(rms: 0.1, keyId: 5, time: Double(frame) * 0.02) != nil { onsets += 1 }
        XCTAssertEqual(onsets, 2)
    }

    func testNoiseBelowTheGateIsIgnored() {
        var detector = OnsetDetector(noiseGate: 0.05)
        for frame in 0..<5 {
            XCTAssertNil(detector.process(rms: 0.02, keyId: 5, time: Double(frame) * 0.02))
        }
    }

    func testAFlickeringKeyNeverSettles() {
        var detector = OnsetDetector()
        for frame in 0..<10 {
            XCTAssertNil(detector.process(rms: 0.1, keyId: frame % 2 == 0 ? 5 : 6, time: Double(frame) * 0.02))
        }
    }

    // MARK: vDSP against the scalar original

    /// The textbook scalar YIN the app used before the Accelerate version, kept here as the reference.
    private func detectReference(samples: [Float], sampleRate: Double) -> Double? {
        let tauMin = max(2, Int(sampleRate / PitchDetector.frequencyRange.upperBound))
        let tauMax = Int(sampleRate / PitchDetector.frequencyRange.lowerBound)
        let window = samples.count - tauMax
        guard window >= tauMax, tauMin < tauMax else { return nil }
        var normalized = [Float](repeating: 1, count: tauMax + 1)
        var runningSum: Float = 0
        for tau in 1...tauMax {
            var difference: Float = 0
            for i in 0..<window {
                let delta = samples[i] - samples[i + tau]
                difference += delta * delta
            }
            runningSum += difference
            normalized[tau] = runningSum > 0 ? difference * Float(tau) / runningSum : 1
        }
        var tau = tauMin
        while tau < tauMax {
            if normalized[tau] < PitchDetector.threshold {
                while tau + 1 < tauMax, normalized[tau + 1] < normalized[tau] { tau += 1 }
                guard tau > 1, tau + 1 < normalized.count else { return sampleRate / Double(tau) }
                let before = Double(normalized[tau - 1]), here = Double(normalized[tau]), after = Double(normalized[tau + 1])
                let denominator = before - 2 * here + after
                let refined = abs(denominator) > 1e-12 ? Double(tau) + (before - after) / (2 * denominator) : Double(tau)
                return sampleRate / refined
            }
            tau += 1
        }
        return nil
    }

    func testAccelerateVersionMatchesTheScalarOriginal() throws {
        for sampleRate in [44100.0, 48000.0] {
            for frequency in [175.0, 440.0, 1000.0] {
                let samples = sine(frequency, sampleRate: sampleRate)
                let fast = try XCTUnwrap(PitchDetector.detect(samples: samples, sampleRate: sampleRate), "\(frequency) Hz")
                let reference = try XCTUnwrap(detectReference(samples: samples, sampleRate: sampleRate))
                XCTAssertEqual(fast, reference, accuracy: 0.5, "\(frequency) Hz at \(sampleRate)")
            }
        }
    }

    func testAccelerateVersionAgreesOnASineWithOvertonesAndNoise() throws {
        var generator = SeededRandom(seed: 11)
        let samples: [Float] = (0..<2048).map { i in
            let t = Double(i) / 44100
            let tone = 0.4 * sin(2 * Double.pi * 330 * t) + 0.2 * sin(2 * Double.pi * 660 * t)
            return Float(tone + Double.random(in: -0.02...0.02, using: &generator))
        }
        let fast = try XCTUnwrap(PitchDetector.detect(samples: samples, sampleRate: 44100))
        let reference = try XCTUnwrap(detectReference(samples: samples, sampleRate: 44100))
        XCTAssertEqual(fast, reference, accuracy: 0.5)
        XCTAssertEqual(fast, 330, accuracy: 3)
    }

    func testAWorkspaceCanBeReusedAcrossCallsAndSampleRates() throws {
        let workspace = PitchDetector.Workspace()
        let low = try XCTUnwrap(PitchDetector.detect(samples: sine(220), sampleRate: 44100, workspace: workspace))
        let high = try XCTUnwrap(PitchDetector.detect(samples: sine(880, sampleRate: 48000), sampleRate: 48000, workspace: workspace))
        let again = try XCTUnwrap(PitchDetector.detect(samples: sine(220), sampleRate: 44100, workspace: workspace))
        XCTAssertEqual(low, 220, accuracy: 1)
        XCTAssertEqual(high, 880, accuracy: 3)
        XCTAssertEqual(again, low, accuracy: 1e-6)
    }
}
