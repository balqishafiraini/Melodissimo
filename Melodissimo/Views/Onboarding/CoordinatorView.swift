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
    /// Posted by the iPhone version of the post-play score page: back to Home, whatever the stack held.
    static let skillTestFinished = Notification.Name("melodissimo.skillTestFinished")
}

struct CoordinatorView: View {
    @State private var isActive = false
    /// Set when the first-run flow ends on iPhone (see `Notification.Name.onboardingFinished`).
    @State private var finishedOnboarding = false
    @State private var startsFirstStage = false
    
    let isPreplayDone = UserDefaults.standard.bool(forKey: "isPreplayDone")

    var body: some View {
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
