//
//  MicrophoneInput.swift
//  Melodissimo
//

import AVFoundation
import QuartzCore

/// Listens to the microphone and reports the pianika key being played: a 2048-sample tap, YIN pitch
/// detection every 1024 samples, and an `OnsetDetector` that confirms each new note.
final class MicrophoneInput: ObservableObject {
    enum Status: Equatable {
        case stopped, running, denied, failed
    }

    static let bufferSize: AVAudioFrameCount = 2048
    static let hop = 1024
    static let noiseGate: Float = 0.01

    @Published private(set) var status: Status = .stopped
    /// The key heard right now (updates every frame, for the calibration screen and the pressed-key look).
    @Published private(set) var currentKeyId: Int?

    /// Called on the main thread for every confirmed onset with the host time the note began.
    var onNote: ((_ keyId: Int, _ hostTime: CFTimeInterval) -> Void)?

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "melodissimo.mic", qos: .userInteractive)
    private var onsets = OnsetDetector(noiseGate: MicrophoneInput.noiseGate)
    private var window: [Float] = []
    private var windowStart: CFTimeInterval = 0
    private var isTapInstalled = false

    /// Asks for permission if needed, then starts listening.
    func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                granted ? self.begin() : (self.status = .denied)
            }
        }
    }

    func stop() {
        guard isTapInstalled else { status = status == .running ? .stopped : status; return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isTapInstalled = false
        status = .stopped
        currentKeyId = nil
        // Back to the playback-only session the samples use.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    deinit {
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
    }

    private func begin() {
        guard !isTapInstalled else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            status = .failed
            return
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { status = .failed; return }
        onsets.reset()
        window.removeAll(keepingCapacity: true)
        input.installTap(onBus: 0, bufferSize: Self.bufferSize, format: format) { [weak self] buffer, when in
            self?.handle(buffer: buffer, at: when, sampleRate: format.sampleRate)
        }
        isTapInstalled = true
        do {
            try engine.start()
            status = .running
        } catch {
            input.removeTap(onBus: 0)
            isTapInstalled = false
            status = .failed
        }
    }

    /// Runs on the audio thread: copy the samples and hand the analysis to our own queue.
    private func handle(buffer: AVAudioPCMBuffer, at when: AVAudioTime, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let start = when.isHostTimeValid ? AVAudioTime.seconds(forHostTime: when.hostTime) : CACurrentMediaTime()
        queue.async { [weak self] in self?.analyse(samples, start: start, sampleRate: sampleRate) }
    }

    private func analyse(_ samples: [Float], start: CFTimeInterval, sampleRate: Double) {
        if window.isEmpty { windowStart = start }
        window.append(contentsOf: samples)
        // Slide a 2048-sample window forward one hop at a time.
        while window.count >= Int(Self.bufferSize) {
            let frame = Array(window.prefix(Int(Self.bufferSize)))
            let level = PitchDetector.rms(of: frame)
            let key = PitchDetector.detect(samples: frame, sampleRate: sampleRate).flatMap(PitchMapper.keyId(forFrequency:))
            let frameTime = windowStart
            let onset = onsets.process(rms: level, keyId: key, time: frameTime)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentKeyId = level >= Self.noiseGate ? key : nil
                if let onset { self.onNote?(onset.keyId, onset.time) }
            }
            window.removeFirst(Self.hop)
            windowStart += Double(Self.hop) / sampleRate
        }
    }
}
