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

    static func isAvailable(for songId: String, bundle: Bundle = .main) -> Bool {
        bundle.url(forResource: resourceName(for: songId), withExtension: "m4a") != nil
    }

    private var player: AVAudioPlayer?
    private var speed = 1.0
    private var driftTimer: Timer?
    /// Where the track was started: its position and the host time at which that position is heard.
    private var anchor: (position: Double, host: CFTimeInterval)?

    /// Loads the track for a song. `offset` is only used to validate the chart (the engine's events carry the clock).
    func load(songId: String, offset: Double, speed: Double, bundle: Bundle = .main) {
        stop()
        self.speed = speed
        guard let url = bundle.url(forResource: Self.resourceName(for: songId), withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.enableRate = true            // before prepareToPlay
        player.rate = Float(speed)
        player.volume = Self.volume
        player.prepareToPlay()
        self.player = player
        self.offset = offset
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

    /// Re-seeks when the track and the song clock have drifted apart (a slow rate, a busy device).
    private func checkDrift() {
        guard let player, player.isPlaying, let anchor else { return }
        let now = CACurrentMediaTime()
        guard now - anchor.host >= Self.driftGrace else { return }
        let expected = anchor.position + (now - anchor.host) * speed
        if BackingSchedule.needsResync(expected: expected, actual: player.currentTime) {
            player.currentTime = expected
        }
    }
}
