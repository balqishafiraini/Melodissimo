//
//  BackingTrackPlayer.swift
//  Melodissimo
//

import Foundation
import AVFoundation
import QuartzCore

/// Plays a song's instrumental (`bgm_<songId>.m4a`) in step with the stage's song clock by following the
/// engine's `ClockEvent`s: seek and start on `.running`, pause on `.halted`, fade out on `.finished`.
/// A missing file makes every call a no-op.
final class BackingTrackPlayer: ObservableObject {
    /// The track sits under the pianika notes and the effects.
    static let volume: Float = 0.55
    /// How often the drift check runs, and how long it waits after a start before judging.
    private static let driftInterval: TimeInterval = 1
    private static let driftGrace: TimeInterval = 0.5
    private static let fadeOut: TimeInterval = 1.2

    static func resourceName(for songId: String) -> String { "bgm_\(songId)" }

    /// The file for a song's instrumental: the content store's (downloaded pack, else the bundled baseline), then the
    /// app bundle's legacy `bgm_<slug>.m4a`. `nil` when it isn't on the device (yet).
    static func url(for songId: String, bundle: Bundle = .main) -> URL? {
        if bundle === Bundle.main, let url = SongLibrary.contentStore.backingURL(songId: songId) { return url }
        return bundle.url(forResource: resourceName(for: songId), withExtension: "m4a")
    }

    static func isAvailable(for songId: String, bundle: Bundle = .main) -> Bool {
        url(for: songId, bundle: bundle) != nil
    }

    /// The asset key of a song's backing track when the active pack lists one that isn't on the device yet, so the stage
    /// setup screen can download it.
    static func downloadableKey(for songId: String) -> String? {
        let store = SongLibrary.contentStore
        guard let key = store.manifestSong(id: songId)?.backing, store.url(forAsset: key) == nil else { return nil }
        return key
    }

    private var player: AVAudioPlayer?
    private var speed = 1.0
    private var driftTimer: Timer?
    private var gate = DriftGate()
    /// Where the track was started: its position and the host time at which that position is heard.
    private var anchor: (position: Double, host: CFTimeInterval)?

    /// Loads the track for a song. The file is opened and primed off the main thread (doing it in `onAppear` froze
    /// the first frames of the stage); the player is published on the main actor when it is ready, and the caller
    /// starts the song clock only after this returns. `offset` is the chart's, for the start position maths.
    @MainActor
    func load(songId: String, offset: Double, speed: Double, bundle: Bundle = .main) async {
        stop()
        self.speed = speed
        self.offset = offset
        gate.reset()
        guard let url = Self.url(for: songId, bundle: bundle) else { return }
        let loaded = await Task.detached(priority: .userInitiated) { () -> AVAudioPlayer? in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.enableRate = true            // before prepareToPlay
            player.rate = Float(speed)
            player.volume = Self.volume
            player.prepareToPlay()
            return player
        }.value
        // The stage may have gone away (or been left and re-entered) while the file was loading.
        guard !Task.isCancelled else { return }
        self.player = loaded
    }

    private var offset = 0.0

    func handle(_ event: RhythmEngine.ClockEvent) {
        guard let player else { return }
        switch event {
        case let .running(songTime, hostTime):
            configureAudioSessionIfNeeded()
            let latency = AudioSessionController.shared.outputLatency
            let plan = BackingSchedule.start(songTime: songTime, speed: speed, offset: offset, outputLatency: latency)
            player.pause()
            guard plan.position < player.duration else { return }
            player.setVolume(Self.volume, fadeDuration: 0)
            player.currentTime = plan.position
            let wait = max(0, hostTime - CACurrentMediaTime()) + plan.delay
            player.play(atTime: player.deviceCurrentTime + wait)
            anchor = (plan.position, CACurrentMediaTime() + wait)
            gate.reset()
            startDriftTimer()
        case .halted:
            stopDriftTimer()
            player.pause()
            anchor = nil
        case .finished:
            stopDriftTimer()
            anchor = nil
            player.setVolume(0, fadeDuration: Self.fadeOut)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeOut + 0.1) { [weak self] in
                self?.player?.stop()
            }
        }
    }

    func stop() {
        stopDriftTimer()
        anchor = nil
        player?.stop()
        player = nil
    }

    deinit {
        stop()
    }

    // MARK: Drift

    private func startDriftTimer() {
        stopDriftTimer()
        let timer = Timer(timeInterval: Self.driftInterval, repeats: true) { [weak self] _ in self?.checkDrift() }
        RunLoop.main.add(timer, forMode: .common)
        driftTimer = timer
    }

    private func stopDriftTimer() {
        driftTimer?.invalidate()
        driftTimer = nil
    }

    /// Re-seeks when the track and the song clock have drifted apart for good (a slow rate, a busy device); see `DriftGate`.
    private func checkDrift() {
        guard let player, player.isPlaying, let anchor else { return }
        let now = CACurrentMediaTime()
        guard now - anchor.host >= Self.driftGrace else { return }
        let expected = anchor.position + (now - anchor.host) * speed
        if gate.shouldResync(drift: expected - player.currentTime, now: now) {
            AudioDiag.log("backing track resync: drift \(expected - player.currentTime)")
            player.currentTime = expected
        }
    }
}
