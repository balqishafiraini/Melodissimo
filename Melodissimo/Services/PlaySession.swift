//
//  PlaySession.swift
//  Melodissimo
//

import UIKit

/// Whether a play screen is open. While one is, the phone must not auto-lock (Listen mode and the microphone
/// mode have no touches, so the screen would dim and lock mid-song) and background work that would stutter a song
/// (the iCloud merge) waits.
///
/// Screens overlap for a moment during a push or replace, so `begin` / `end` are counted: the idle timer comes
/// back on only when the last play screen has gone. Main thread only; `.playScreen()` drives it.
enum PlaySession {
    private static var depth = 0

    static private(set) var isActive = false {
        didSet { PlaySessionState.shared.isActive = isActive }
    }

    static func begin() {
        depth += 1
        guard depth == 1 else { return }
        isActive = true
        UIApplication.shared.isIdleTimerDisabled = true
        AudioDiag.log("play session begin: idleTimerDisabled = \(UIApplication.shared.isIdleTimerDisabled)")
        #if DEBUG
        logSystemUI(after: 0.6)
        #endif
    }

    static func end() {
        guard depth > 0 else { return }
        depth -= 1
        guard depth == 0 else { return }
        isActive = false
        UIApplication.shared.isIdleTimerDisabled = false
        AudioDiag.log("play session end: idleTimerDisabled = \(UIApplication.shared.isIdleTimerDisabled)")
        #if DEBUG
        logSystemUI(after: 0.6)
        #endif
        // The writes made during play skipped the iCloud merge; do one now.
        CloudSync.shared.syncSoon()
    }

    #if DEBUG
    /// What UIKit's root view controller currently asks the system for, once SwiftUI has had time to pass the
    /// preferences up. `edges` 15 = all four edges deferred. This is how the deferral is verified on a simulator,
    /// where a swipe can't be told apart from the home gesture.
    private static func logSystemUI(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            guard let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
            let top = sequence(first: root) { $0.presentedViewController }.reduce(root) { _, next in next }
            AudioDiag.log("system UI asked of UIKit: deferred edges = \(top.preferredScreenEdgesDeferringSystemGestures.rawValue), "
                          + "home indicator hidden = \(top.prefersHomeIndicatorAutoHidden)")
        }
    }
    #endif
}

/// `PlaySession.isActive` as something a view can observe. The home indicator and edge-gesture deferral only take
/// effect when asked for at the root of the navigation stack (asked for inside a pushed screen they are ignored),
/// so Home's root reads this; see `playSessionSystemUI()`.
final class PlaySessionState: ObservableObject {
    static let shared = PlaySessionState()
    @Published fileprivate(set) var isActive = false
}
