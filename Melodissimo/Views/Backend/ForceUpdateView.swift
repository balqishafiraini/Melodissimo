//
//  ForceUpdateView.swift
//  Melodissimo
//

import SwiftUI

/// The screen that stops an old or blocked build (`update.action == hard`): logo, the server's message in the player's
/// language (or the built-in one), and an Update button. There is no way past it, except in Debug builds.
struct ForceUpdateView: View {
    let info: Bootstrap.UpdateInfo?
    /// Debug builds can dismiss the screen; Release builds pass `nil`.
    var onDebugDismiss: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    private var title: String {
        info?.title?.resolved() ?? NSLocalizedString("Update needed", comment: "")
    }

    private var message: String {
        info?.message?.resolved() ?? NSLocalizedString("Please update Melodissimo to keep playing.", comment: "")
    }

    var body: some View {
        ZStack {
            Color.softBlue.ignoresSafeArea()
            VStack(spacing: Sizing.s(20)) {
                AssetImage(name: "alpanica", fallbackEmoji: "🦙")
                    .frame(height: Sizing.isPhone ? 90 : 220)
                Text(title)
                    .font(.custom("BalooDa-Regular", size: Sizing.f(48)))
                    .foregroundColor(Color.darkGreen)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.headline)
                    .foregroundColor(Color.darkGreen)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                if let url = UpdateGate.storeURL(info?.storeUrl) {
                    SoundButton {
                        openURL(url)
                    } label: {
                        Text("Update")
                            .frame(minWidth: Sizing.s(260))
                            .frame(height: Sizing.tap(64))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(.custom("BalooDa-Regular", size: Sizing.f(32)))
                    }
                }
                if let onDebugDismiss {
                    Button("Dismiss (debug only)", action: onDebugDismiss)
                        .font(.caption)
                }
            }
            .padding(Sizing.s(30))
        }
        .accessibilityElement(children: .contain)
        .onAppear { Analytics.log(.updatePromptShown, props: ["kind": "hard"]) }
    }
}

/// The dismissible prompt for a recommended update (`update.action == soft`), shown on Home.
struct SoftUpdateSheet: View {
    let info: Bootstrap.UpdateInfo?
    let onLater: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Sizing.s(16)) {
            Text(info?.title?.resolved() ?? NSLocalizedString("A new version is available", comment: ""))
                .font(.custom("BalooDa-Regular", size: Sizing.f(36)))
                .foregroundColor(Color.darkGreen)
                .multilineTextAlignment(.center)
            Text(info?.message?.resolved() ?? NSLocalizedString("Update Melodissimo for the latest songs and features.", comment: ""))
                .font(.headline)
                .multilineTextAlignment(.center)
            HStack(spacing: Sizing.s(14)) {
                SoundButton(action: onLater) {
                    Text("Later")
                        .frame(maxWidth: .infinity)
                        .frame(height: Sizing.tap(56))
                        .background(Color.white)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(Sizing.s(18))
                        .font(.headline)
                }
                if let url = UpdateGate.storeURL(info?.storeUrl) {
                    SoundButton {
                        openURL(url)
                        onLater()
                    } label: {
                        Text("Update")
                            .frame(maxWidth: .infinity)
                            .frame(height: Sizing.tap(56))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(18))
                            .font(.headline)
                    }
                }
            }
        }
        .padding(Sizing.s(28))
        .frame(maxWidth: 520)
        .background(Color.softBlue.ignoresSafeArea())
        .presentationDetents([.medium])
        .onAppear { Analytics.log(.updatePromptShown, props: ["kind": "soft"]) }
    }
}
