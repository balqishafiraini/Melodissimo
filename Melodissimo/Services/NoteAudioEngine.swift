//
//  NoteAudioEngine.swift
//  Melodissimo
//

import Foundation
import AVFoundation

/// Plays the 32 pianika notes and the short game effects on one `AVAudioEngine`.
///
/// Why not `AVAudioPlayer`: its `stop()` undoes `prepareToPlay()`, so after a note was released the next press of
/// that key had to re-acquire and re-prime the file, tens of milliseconds late on a phone. Here every sample is
/// decoded once into a PCM buffer, and a press is just "schedule this buffer on a free voice and play", with the
/// engine already running. Releasing a key fades the voice out over 15 ms (no click) instead of cutting it.
///
/// - **Voices:** 12 player nodes for notes into `notesMixer`, 6 for effects into `sfxMixer` (at `SFX.volume`), both
///   into the main mixer. `VoiceAllocator` decides who gets which note voice.
/// - **Format:** every buffer is mono float at 48 kHz, so no buffer ever needs re-converting when the route's rate
///   changes (the mixers resample). Pianika samples are mono anyway, and a note longer than 3 s keeps its first 3 s
///   (a chart's notes are far shorter), which keeps all 32 under 20 MB.
/// - **Robustness:** the engine restarts itself after a configuration change (a route change, or the microphone
///   switching the session category, both of which stop an engine), after an interruption, and is rebuilt after a
///   media-services reset.
///
/// Main thread only, apart from `makeBuffer`, which is pure and meant for a background queue.
final class NoteAudioEngine {
    static let shared = NoteAudioEngine()

    static let noteVoiceCount = 12
    static let effectVoiceCount = 6
    /// The one format every buffer is converted to.
    static let sampleRate = 48_000.0
    /// Longest note kept, in seconds.
    static let maxNoteSeconds = 3.0
    /// How long a released note takes to fade out.
    static let fadeSeconds = 0.015
    private static let fadeSteps = 3

    static let bufferFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    private var engine = AVAudioEngine()
    private var notesMixer = AVAudioMixerNode()
    private var sfxMixer = AVAudioMixerNode()
    private var noteNodes: [AVAudioPlayerNode] = []
    private var effectNodes: [AVAudioPlayerNode] = []
    private var allocator = VoiceAllocator(count: noteVoiceCount)
    private var noteBuffers: [String: AVAudioPCMBuffer] = [:]
    private var nextEffectVoice = 0
    private var lastNote: String?
    private var observers: [NSObjectProtocol] = []

    /// How many note samples are decoded and ready to play.
    var noteBufferCount: Int { noteBuffers.count }
    var isRunning: Bool { engine.isRunning }

    private init() {
        buildGraph()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] note in
            // Only our own engine: the microphone input has an engine of its own.
            guard let self, (note.object as? AVAudioEngine) === self.engine else { return }
            self.restart(reason: "configuration change")
        })
        observers.append(center.addObserver(forName: AudioSessionController.didResume, object: nil, queue: .main) { [weak self] _ in
            self?.restart(reason: "interruption ended")
        })
        observers.append(center.addObserver(forName: AudioSessionController.mediaReset, object: nil, queue: .main) { [weak self] _ in
            self?.rebuild()
        })
    }

    // MARK: Graph

    /// A fresh engine with every node attached and connected. Buffers are kept by the caller.
    private func buildGraph() {
        engine = AVAudioEngine()
        notesMixer = AVAudioMixerNode()
        sfxMixer = AVAudioMixerNode()
        sfxMixer.outputVolume = SFX.volume
        engine.attach(notesMixer)
        engine.attach(sfxMixer)
        engine.connect(notesMixer, to: engine.mainMixerNode, format: nil)
        engine.connect(sfxMixer, to: engine.mainMixerNode, format: nil)
        noteNodes = (0..<Self.noteVoiceCount).map { _ in makeNode(into: notesMixer) }
        effectNodes = (0..<Self.effectVoiceCount).map { _ in makeNode(into: sfxMixer) }
        allocator = VoiceAllocator(count: Self.noteVoiceCount)
        engine.prepare()
    }

    private func makeNode(into mixer: AVAudioMixerNode) -> AVAudioPlayerNode {
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: mixer, format: Self.bufferFormat)
        return node
    }

    /// Starts the engine if it isn't running. Returns whether it is running afterwards.
    @discardableResult
    func ensureRunning() -> Bool {
        if engine.isRunning { return true }
        configureAudioSessionIfNeeded()
        do {
            try engine.start()
            AudioDiag.log("note engine started (output \(engine.outputNode.outputFormat(forBus: 0).sampleRate) Hz)")
            return true
        } catch {
            AudioDiag.log("note engine failed to start: \(error)")
            return false
        }
    }

    private func restart(reason: String) {
        AudioDiag.log("note engine restart: \(reason)")
        engine.stop()
        ensureRunning()
    }

    private func rebuild() {
        AudioDiag.log("note engine rebuild")
        engine.stop()
        buildGraph()
        ensureRunning()
    }

    // MARK: Buffers

    /// Decodes an audio file into the shared mono 48 kHz format. `maxSeconds` keeps only the start of a long file
    /// (with a short fade so the cut doesn't click). Pure: safe off the main thread. `nil` when the file can't be read.
    static func makeBuffer(url: URL, maxSeconds: Double? = nil) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let source = file.processingFormat
        var frames = file.length
        var trimmed = false
        if let maxSeconds {
            let limit = AVAudioFramePosition(maxSeconds * source.sampleRate)
            if frames > limit { frames = limit; trimmed = true }
        }
        guard frames > 0, let raw = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        do { try file.read(into: raw, frameCount: AVAudioFrameCount(frames)) } catch { return nil }

        let buffer: AVAudioPCMBuffer
        if source == bufferFormat {
            buffer = raw
        } else {
            guard let converter = AVAudioConverter(from: source, to: bufferFormat) else { return nil }
            let capacity = AVAudioFrameCount(Double(raw.frameLength) * bufferFormat.sampleRate / source.sampleRate) + 1024
            guard let converted = AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: capacity) else { return nil }
            var supplied = false
            var failure: NSError?
            let status = converter.convert(to: converted, error: &failure) { _, outStatus in
                if supplied { outStatus.pointee = .endOfStream; return nil }
                supplied = true
                outStatus.pointee = .haveData
                return raw
            }
            guard status != .error, converted.frameLength > 0 else { return nil }
            buffer = converted
        }
        if trimmed { fadeOutTail(of: buffer, seconds: 0.05) }
        return buffer
    }

    private static func fadeOutTail(of buffer: AVAudioPCMBuffer, seconds: Double) {
        guard let samples = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        let fade = min(count, Int(seconds * buffer.format.sampleRate))
        guard fade > 0 else { return }
        for index in 0..<fade {
            samples[count - fade + index] *= Float(fade - 1 - index) / Float(fade)
        }
    }

    /// Decodes all 32 note samples on a background queue, then keeps them and starts the engine. `completion`
    /// runs on the main thread when they are ready.
    func preloadNotes(completion: (() -> Void)? = nil) {
        let files = NoteCatalog.all.map { ($0.sound, Bundle.main.url(forResource: $0.sound, withExtension: "m4a")) }
        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [String: AVAudioPCMBuffer] = [:]
            for (name, url) in files {
                if let url, let buffer = Self.makeBuffer(url: url, maxSeconds: Self.maxNoteSeconds) { loaded[name] = buffer }
            }
            DispatchQueue.main.async {
                for (name, buffer) in loaded where self.noteBuffers[name] == nil { self.noteBuffers[name] = buffer }
                self.ensureRunning()
                completion?()
            }
        }
    }

    // MARK: Notes

    /// Plays a note, cutting the previous sound of the same note. Without a decoded sample (not yet preloaded) the
    /// note is decoded on the spot, once.
    func play(note: String) {
        guard let buffer = noteBuffer(for: note), ensureRunning() else { return }
        let start = allocator.start(note: note)
        let node = noteNodes[start.voice]
        node.stop()
        node.volume = 1
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        node.play()
        lastNote = note
    }

    private func noteBuffer(for note: String) -> AVAudioPCMBuffer? {
        if let buffer = noteBuffers[note] { return buffer }
        guard let url = Bundle.main.url(forResource: note, withExtension: "m4a"),
              let buffer = Self.makeBuffer(url: url, maxSeconds: Self.maxNoteSeconds) else { return nil }
        noteBuffers[note] = buffer
        return buffer
    }

    /// Releases a note with a 15 ms fade. Does nothing for a note that isn't sounding, and nothing at the end of
    /// the fade if the note was pressed again meanwhile.
    func stop(note: String) {
        guard let release = allocator.release(note: note) else { return }
        let node = noteNodes[release.voice]
        let step = Self.fadeSeconds / Double(Self.fadeSteps)
        for index in 1...Self.fadeSteps {
            let volume = Float(Self.fadeSteps - index) / Float(Self.fadeSteps)
            DispatchQueue.main.asyncAfter(deadline: .now() + step * Double(index - 1)) { [weak self, weak node] in
                guard let self, let node, self.allocator.isCurrent(voice: release.voice, generation: release.generation) else { return }
                node.volume = volume
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeSeconds) { [weak self, weak node] in
            guard let self, let node, self.allocator.finishRelease(release) else { return }
            node.stop()
        }
    }

    /// Releases the note that was played last (the old "stop the current sound").
    func stopLast() {
        if let lastNote { stop(note: lastNote) }
    }

    /// Cuts every note at once. Used when a screen goes away; with an engine nothing gets un-prepared by it.
    func stopAllNotes() {
        for voice in allocator.stopAll() { noteNodes[voice].stop() }
        lastNote = nil
    }

    // MARK: Effects

    /// Plays an effect buffer on the next effect voice. Returns whether it was handed to a running engine.
    @discardableResult
    func playEffect(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard ensureRunning() else { return false }
        let node = effectNodes[nextEffectVoice]
        nextEffectVoice = (nextEffectVoice + 1) % effectNodes.count
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        node.play()
        return true
    }
}
