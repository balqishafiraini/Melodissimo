//
//  CoordinatorView.swift
//  Melodissimo
//
//  Created by Balqis on 02/11/23.
//

import SwiftUI

extension Notification.Name {
    /// Posted by the iPhone version of the pre-play score page: the new player's first-run flow is over and Home should
    /// become the root screen (a `Home` pushed inside the old `NavigationView` stack comes up blank on iPhone).
    static let onboardingFinished = Notification.Name("melodissimo.onboardingFinished")
}

struct CoordinatorView: View {
    @State private var isActive = false
    /// Set when the first-run flow ends on iPhone (see `Notification.Name.onboardingFinished`).
    @State private var finishedOnboarding = false
    @State private var startsFirstStage = false
    /// Debug builds can dismiss the blocking update screen.
    @State private var debugDismissedUpdate = false
    @ObservedObject private var bootstrap = BootstrapService.shared
    @ObservedObject private var playState = PlaySessionState.shared
    
    let isPreplayDone = UserDefaults.standard.bool(forKey: "isPreplayDone")

    private var dismissesUpdateInDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            content
            // The update and maintenance screens sit above everything, but never interrupt a song: during play they wait
            // and appear when the play screen closes.
            if UpdateGate.showsBlockingScreen(directive: bootstrap.directive, isPlaying: playState.isActive),
               !(dismissesUpdateInDebug && debugDismissedUpdate) {
                ForceUpdateView(info: bootstrap.current?.update,
                                onDebugDismiss: dismissesUpdateInDebug ? { debugDismissedUpdate = true } : nil)
                    .transition(.opacity)
            } else if UpdateGate.showsMaintenanceScreen(bootstrap.maintenance, isPlaying: playState.isActive),
                      let info = bootstrap.maintenance {
                MaintenanceView(info: info)
            }
        }
    }

    private var content: some View {
        Group {
            #if DEBUG
            // `-qaOnboarding <name>` shows one first-run screen directly (see QARoutes).
            if QARoutes.hasOnboardingScreen && !finishedOnboarding {
                QARoutes.onboardingScreen()
            } else {
                flow
            }
            #else
            flow
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingFinished)) { note in
            startsFirstStage = (note.userInfo?["startsFirstStage"] as? Bool) ?? false
            isActive = true
            finishedOnboarding = true
        }
    }

    @ViewBuilder
    private var flow: some View {
        if isActive {
            if isPreplayDone || finishedOnboarding {
                DashboardView(startsFirstStage: startsFirstStage)
            } else {
                FirstLaunchView()
            }
        }else {
            SplashscreenView(isActive: $isActive)
        }
    }
}
