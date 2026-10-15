//
//  MicrophoneInput.swift
//  Melodissimo
//

import AVFoundation
import QuartzCore

/// Listens to the microphone and reports the pianika key being played: a 2048-sample tap, YIN pitch
/// detection every 1024 samples, and an `OnsetDetector` that confirms each new note.
///
/// The `AVAudioEngine` exists only while listening (a stage without Real pianika never creates one). The analysis
/// queue is bounded: when it is more than a few buffers behind (a slow Debug build, a busy phone), new audio is
/// dropped instead of queued, so the work never piles up and the detection stays close to real time. And the main
/// thread is woken only when the heard key changes or a note starts.
final class MicrophoneInput: ObservableObject {
    enum Status: Equatable {
        case stopped, running, denied, failed
    }

    static let bufferSize: AVAudioFrameCount = 2048
    static let hop = 1024
    static let noiseGate: Float = 0.01
    /// More than this many analysis frames of audio waiting means the analysis is behind (or two taps' worth, if
    /// the system delivers taps larger than that): further audio is dropped until it catches up.
    static let maxBacklogBuffers = 4

    @Published private(set) var status: Status = .stopped
    /// The key heard right now (updates every frame, for the calibration screen and the pressed-key look).
    @Published private(set) var currentKeyId: Int?

    /// Called on the main thread for every confirmed onset with the host time the note began.
    var onNote: ((_ keyId: Int, _ hostTime: CFTimeInterval) -> Void)?

    private var engine: AVAudioEngine?
    private let queue = DispatchQueue(label: "melodissimo.mic", qos: .userInteractive)
    private var onsets = OnsetDetector(noiseGate: MicrophoneInput.noiseGate)
    private var window: [Float] = []
    private var windowStart: CFTimeInterval = 0
    private var isTapInstalled = false
    private let workspace = PitchDetector.Workspace()
    /// The key last sent to the main thread (analysis queue only), so unchanged frames send nothing.
    private var lastSentKey: Int?
    /// Samples handed to the analysis queue and not yet analysed, and whether a chunk was dropped since (the next
    /// one then starts a fresh window, since audio is no longer contiguous). Guarded by `backlogLock`.
    private let backlogLock = NSLock()
    private var pendingSamples = 0
    private var droppedSinceLast = false

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
        guard isTapInstalled, let engine else { status = status == .running ? .stopped : status; return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        isTapInstalled = false
        status = .stopped
        currentKeyId = nil
        // Back to the playback-only session the samples use.
        AudioSessionController.shared.activate(.playback)
    }

    deinit {
        if isTapInstalled, let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
    }

    private func begin() {
        guard !isTapInstalled else { return }
        guard AudioSessionController.shared.activate(.record) else {
            status = .failed
            return
        }
        let engine = AVAudioEngine()
        self.engine = engine
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { self.engine = nil; status = .failed; return }
        queue.sync { [self] in
            onsets.reset()
            window.removeAll(keepingCapacity: true)
            lastSentKey = nil
        }
        backlogLock.lock()
        pendingSamples = 0
        droppedSinceLast = false
        backlogLock.unlock()
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
            self.engine = nil
            status = .failed
        }
    }

    /// Runs on the audio thread: copy the samples and hand the analysis to our own queue.
    private func handle(buffer: AVAudioPCMBuffer, at when: AVAudioTime, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        backlogLock.lock()
        let behind = pendingSamples > max(Self.maxBacklogBuffers * Int(Self.bufferSize), 2 * count)
        if behind { droppedSinceLast = true } else { pendingSamples += count }
        backlogLock.unlock()
        if behind {
            AudioDiag.log("mic backlog dropped: \(count) samples")
            return
        }
        let samples = Array(UnsafeBufferPointer(start: channel, count: count))
        let start = when.isHostTimeValid ? AVAudioTime.seconds(forHostTime: when.hostTime) : CACurrentMediaTime()
        queue.async { [weak self] in self?.analyse(samples, start: start, sampleRate: sampleRate) }
    }

    private func analyse(_ samples: [Float], start: CFTimeInterval, sampleRate: Double) {
        backlogLock.lock()
        pendingSamples -= samples.count
        let gap = droppedSinceLast
        droppedSinceLast = false
        backlogLock.unlock()
        // Audio was dropped before this chunk: what is left of the window no longer joins up with it.
        if gap { window.removeAll(keepingCapacity: true) }
        if window.isEmpty { windowStart = start }
        window.append(contentsOf: samples)
        let frameSize = Int(Self.bufferSize)
        // Slide a 2048-sample window forward one hop at a time.
        while window.count >= frameSize {
            let (level, key) = window.withUnsafeBufferPointer { all -> (Float, Int?) in
                let frame = UnsafeBufferPointer(rebasing: all[0..<frameSize])
                let level = PitchDetector.rms(of: frame)
                let key = PitchDetector.detect(samples: frame, sampleRate: sampleRate, workspace: workspace)
                    .flatMap(PitchMapper.keyId(forFrequency:))
                return (level, key)
            }
            let onset = onsets.process(rms: level, keyId: key, time: windowStart)
            let heard = level >= Self.noiseGate ? key : nil
            // The main thread only needs to hear about a change of key or a new note.
            if heard != lastSentKey || onset != nil {
                lastSentKey = heard
                DispatchQueue.main.async { [weak self] in
                    // A frame that was already queued when listening stopped must not light a key afterwards.
                    guard let self, self.isTapInstalled else { return }
                    if self.currentKeyId != heard { self.currentKeyId = heard }
                    if let onset { self.onNote?(onset.keyId, onset.time) }
                }
            }
            window.removeFirst(Self.hop)
            windowStart += Double(Self.hop) / sampleRate
        }
    }
}
