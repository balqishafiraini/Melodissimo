//
//  AudioSessionController.swift
//  Melodissimo
//

import AVFoundation
import UIKit

/// What an `AVAudioSession.interruptionNotification` says, read from its `userInfo`. Pure, so it can be tested
/// without a real interruption (a simulator can't produce one).
enum AudioInterruptionEvent: Equatable {
    case began, ended

    init?(userInfo: [AnyHashable: Any]?) {
        guard let raw = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return nil }
        self = type == .began ? .began : .ended
    }
}

/// The one owner of the app's `AVAudioSession`. Notes, effects, the backing track and the microphone all share
/// one session, so they must agree on its category and on what to do when the system takes it away (a call, Siri,
/// an alarm), when the headphones change, and when the audio daemon restarts.
///
/// Before this existed the session was configured once and then forgotten: after a call it stayed deactivated
/// while the app believed it was fine, so every note was silent until the app was relaunched.
///
/// Anything that needs to react (the stage pausing, the note engine restarting) listens for the notifications
/// posted here. Main thread only.
final class AudioSessionController {
    static let shared = AudioSessionController()

    enum Mode: Equatable {
        /// Notes, effects and the backing track.
        case playback
        /// The microphone is open (Real pianika) and the speaker still plays.
        case record
    }

    /// Posted when the system takes the session away. The stage pauses.
    static let didInterrupt = Notification.Name("melodissimo.audioSession.didInterrupt")
    /// Posted after the session was re-activated at the end of an interruption. The player resumes by hand.
    static let didResume = Notification.Name("melodissimo.audioSession.didResume")
    /// Posted on every route change; `userInfo["reason"]` is the `AVAudioSession.RouteChangeReason` raw value.
    static let routeChanged = Notification.Name("melodissimo.audioSession.routeChanged")
    /// Posted after the audio daemon was reset and the session re-activated. Engines rebuild themselves.
    static let mediaReset = Notification.Name("melodissimo.audioSession.mediaReset")

    /// The mode last activated, or `nil` before the first activation.
    private(set) var mode: Mode?
    /// Whether the session is believed to be active (cleared by an interruption or a media reset).
    private(set) var isActive = false
    private(set) var isInterrupted = false

    /// The current output route's latency, so the backing track lines up after a route change.
    var outputLatency: TimeInterval { AVAudioSession.sharedInstance().outputLatency }

    private init() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] in
            self?.handleInterruption($0)
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] in
            self?.handleRouteChange($0)
        }
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            self?.handleMediaReset()
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            // An interruption whose "ended" never arrived (Siri dismissed, a call declined) leaves it deactivated.
            guard let self, !self.isActive, !self.isInterrupted, let mode = self.mode else { return }
            self.activate(mode)
        }
        // A note must never keep ringing once the app is no longer in front (a call, Control Center, the app switcher).
        center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            stopAllSounds()
        }
    }

    /// Sets the category for `mode` and activates the session. A repeat call for the mode that is already active
    /// does nothing. Returns whether the session is active afterwards.
    @discardableResult
    func activate(_ mode: Mode) -> Bool {
        if isActive, self.mode == mode { return true }
        let session = AVAudioSession.sharedInstance()
        do {
            switch mode {
            case .playback:
                try session.setCategory(.playback, mode: .default, options: [])
            case .record:
                // `.default`, not `.measurement`: measurement mode turns the speaker down.
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            }
            // A small IO buffer keeps tap-to-sound latency low, which matters for the rhythm game.
            try? session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            self.mode = mode
            isActive = true
            AudioDiag.log("session active: \(mode), buffer \(session.ioBufferDuration), latency \(session.outputLatency)")
            return true
        } catch {
            isActive = false
            AudioDiag.log("session activation failed (\(mode)): \(error)")
            return false
        }
    }

    // MARK: Notifications

    private func handleInterruption(_ note: Notification) {
        switch AudioInterruptionEvent(userInfo: note.userInfo) {
        case .began?:
            isInterrupted = true
            isActive = false
            AudioDiag.log("interruption began")
            NotificationCenter.default.post(name: Self.didInterrupt, object: nil)
        case .ended?:
            isInterrupted = false
            // Whatever `shouldResume` says: the game shows its pause overlay and the player resumes by hand.
            let restored = activate(mode ?? .playback)
            AudioDiag.log("interruption ended, session restored: \(restored)")
            NotificationCenter.default.post(name: Self.didResume, object: nil)
        case nil:
            break
        }
    }

    private func handleRouteChange(_ note: Notification) {
        let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
        AudioDiag.log("route change, reason \(raw), output latency \(outputLatency)")
        NotificationCenter.default.post(name: Self.routeChanged, object: nil, userInfo: ["reason": raw])
    }

    private func handleMediaReset() {
        isActive = false
        let restored = activate(mode ?? .playback)
        AudioDiag.log("media services reset, session restored: \(restored)")
        NotificationCenter.default.post(name: Self.mediaReset, object: nil)
    }

    /// The reason carried by a `routeChanged` notification.
    static func routeChangeReason(of note: Notification) -> AVAudioSession.RouteChangeReason? {
        (note.userInfo?["reason"] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
    }
}
