//
//  PlayScreenModifier.swift
//  Melodissimo
//

import SwiftUI

/// What every screen where the player is playing needs: the phone stays awake (`PlaySession`), and swipes from the
/// screen edges are deferred (that half, and the home indicator, is `playSessionSystemUI()` at the stack root). In landscape the pianika keyboard sits right on the home-indicator edge, so a fast
/// run on the lowest keys looked like the start of a swipe home: iOS held those touches back while it decided
/// ("System gesture gate timed out"), which delays the note, and when it decided yes the app went inactive and
/// the song paused. Deferred, the first swipe only shows the home grabber and the second one leaves.
///
/// The home indicator is hidden for the same reason, and the status bar too; the safe area is unchanged, so layouts
/// don't move.
private struct PlayScreenModifier: ViewModifier {
    @State private var isCounted = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !isCounted else { return }
                isCounted = true
                PlaySession.begin()
            }
            .onDisappear {
                guard isCounted else { return }
                isCounted = false
                PlaySession.end()
            }
            .statusBarHidden(Sizing.isPhone)
    }
}

extension View {
    /// Marks a play screen: no auto-lock, no status bar on iPhone (iPad keeps its layout), and (through `PlaySession`) deferred edge gestures and no
    /// home indicator.
    func playScreen() -> some View {
        modifier(PlayScreenModifier())
    }
}

/// Applies the system-UI half of a play screen at the root of the navigation stack: SwiftUI only forwards the
/// home-indicator and edge-gesture requests to UIKit from there. Home's `NavigationStack` uses it once.
private struct PlaySessionSystemUIModifier: ViewModifier {
    @ObservedObject private var state = PlaySessionState.shared

    func body(content: Content) -> some View {
        content
            .persistentSystemOverlays(state.isActive ? .hidden : .automatic)
            .defersSystemGestures(on: state.isActive ? .all : [])
    }
}

extension View {
    /// While a play screen is open: no home indicator, and edge swipes deferred. Apply at the stack's root.
    func playSessionSystemUI() -> some View {
        modifier(PlaySessionSystemUIModifier())
    }
}
