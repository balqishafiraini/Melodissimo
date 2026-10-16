//
//  SettingsView.swift
//  Melodissimo
//

import AuthenticationServices
import SwiftUI

/// How the game plays and feels: how fast notes fall, key labels, audio timing, and a reset. The
/// settings are plain `ProgressStore` values, so every screen picks them up the next time it opens.
struct SettingsView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared

    @State private var isCalibrating = false
    @State private var isTestingMicrophone = false
    /// Observed so a flag change from the server redraws this screen.
    @ObservedObject private var bootstrap = BootstrapService.shared
    @ObservedObject private var entitlements = Entitlements.shared
    @ObservedObject private var account = PlayerAccount.shared
    @State private var accountMessage: LocalizedStringKey?
    @State private var isConfirmingReset = false
    @State private var isReallyConfirmingReset = false
    @State private var didReset = false

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue)

            VStack(spacing: Sizing.s(18)) {
                topBar
                ScrollView {
                    if Sizing.isPhone {
                        // Two columns on iPhone: the page is wide and short, so one tall column would be a long scroll.
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 12) {
                                noteSpeedCard
                                if FeatureFlags.isOn(.micInput) { inputCard }
                                labelsCard
                            noteNamesCard
                                noteNamesCard
                            }
                            VStack(spacing: 12) {
                                soundCard
                                audioCard
                                resetCard
                                plusCard
                            accountCard
                                accountCard
                                plusCard
                            aboutCard
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 20) {
                            noteSpeedCard
                            if FeatureFlags.isOn(.micInput) { inputCard }
                            labelsCard
                            soundCard
                            audioCard
                            resetCard
                            aboutCard
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(Sizing.s(30))
        }
        .fullScreenCover(isPresented: $isCalibrating) {
            CalibrationView()
        }
        .fullScreenCover(isPresented: $isTestingMicrophone) {
            MicCalibrationView()
        }
        #if DEBUG
        .onAppear {
            // `-qaCover calibration|micCalibration` opens a calibration screen for the screenshot scripts.
            switch UserDefaults.standard.string(forKey: "qaCover") {
            case "calibration": isCalibrating = true
            case "micCalibration": isTestingMicrophone = true
            default: break
            }
        }
        #endif
        .alert("Reset progress?", isPresented: $isConfirmingReset) {
            Button("Continue", role: .destructive) { isReallyConfirmingReset = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your stars, coins, shop items and trophies will be erased. What you bought with real money stays.")
        }
        .alert("Are you really sure?", isPresented: $isReallyConfirmingReset) {
            Button("Erase everything", role: .destructive) { resetProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        ZStack {
            Text("Settings")
                .font(Font.largeTitle)
                .foregroundColor(Color.darkGreen)

            HStack {
                SoundButton {
                    router.pop()
                } label: {
                    Text("< Back")
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(minWidth: Sizing.tap(120), minHeight: Sizing.tap(80), maxHeight: Sizing.tap(80))
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(Sizing.s(20))
                        .font(Font.headline)
                }
                Spacer()
            }
        }
    }

    private func card<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Sizing.isPhone ? 8 : 14) {
            Text(title)
                .font(.custom("BalooDa-Regular", size: Sizing.f(30)))
                .foregroundColor(Color.darkGreen)
            content()
        }
        .padding(Sizing.isPhone ? 14 : 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Sizing.s(28)).fill(Color.white))
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(Color.darkGreen.opacity(0.75))
            // On iPhone the two columns are narrow and a longer (Indonesian) caption must wrap, not end in "…".
            .fixedSize(horizontal: false, vertical: Sizing.isPhone)
    }

    // MARK: Note speed

    private var noteSpeedCard: some View {
        card("Note speed") {
            HStack(spacing: Sizing.isPhone ? 6 : 12) {
                ForEach(ProgressStore.approachTimeChoices, id: \.self) { seconds in
                    SoundButton {
                        progress.approachTime = seconds
                    } label: {
                        Text(String(format: "%.1f s", seconds))
                            .frame(maxWidth: .infinity)
                            .frame(height: Sizing.tap(60))
                            .background(progress.approachTime == seconds ? Color.darkGreen : Color.softBlue.opacity(0.5))
                            .foregroundColor(progress.approachTime == seconds ? .white : Color.darkGreen)
                            .cornerRadius(Sizing.s(18))
                            .font(.custom("BalooDa-Regular", size: Sizing.f(26)))
                    }
                    .accessibilityAddTraits(progress.approachTime == seconds ? .isSelected : [])
                }
            }
            caption("How long a note takes to fall. A bigger number means slower notes.")
        }
    }

    // MARK: Input

    private var inputCard: some View {
        card("Input") {
            HStack(spacing: Sizing.isPhone ? 6 : 12) {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    SoundButton {
                        progress.inputMode = mode
                    } label: {
                        Text(mode == .touch ? "Touch" : "Real pianika")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .frame(height: Sizing.tap(60))
                            .background(progress.inputMode == mode ? Color.darkGreen : Color.softBlue.opacity(0.5))
                            .foregroundColor(progress.inputMode == mode ? .white : Color.darkGreen)
                            .cornerRadius(Sizing.s(18))
                            .font(.custom("BalooDa-Regular", size: Sizing.f(26)))
                    }
                    .accessibilityAddTraits(progress.inputMode == mode ? .isSelected : [])
                }
            }
            if progress.inputMode == .pianika {
                SoundButton {
                    isTestingMicrophone = true
                } label: {
                    Text("Test the microphone")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, Sizing.s(28))
                        .frame(height: Sizing.tap(60))
                        .background(Color.yellow)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(Sizing.s(18))
                        .font(Font.headline)
                }
            }
            caption("Play the songs on your own pianika. Your device listens through the microphone, so play in a quiet room.")
        }
    }

    // MARK: Labels

    private var labelsCard: some View {
        card("Key labels") {
            Toggle(isOn: Binding(get: { progress.labelsInPerform }, set: { progress.labelsInPerform = $0 })) {
                Text("Show key labels in Perform")
                    .font(Font.headline)
                    .foregroundColor(Color.darkGreen)
            }
            .tint(Color.darkGreen)
            caption("Practice and Listen always show them.")
        }
    }

    // MARK: Note names

    private var noteNamesCard: some View {
        card("Note names") {
            HStack(spacing: Sizing.isPhone ? 6 : 12) {
                ForEach(NoteLabelStyle.allCases, id: \.self) { style in
                    SoundButton {
                        progress.noteLabelStyle = style
                    } label: {
                        Text(Self.title(of: style))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .frame(height: Sizing.tap(60))
                            .background(progress.noteLabelStyle == style ? Color.darkGreen : Color.softBlue.opacity(0.5))
                            .foregroundColor(progress.noteLabelStyle == style ? .white : Color.darkGreen)
                            .cornerRadius(Sizing.s(18))
                            .font(.custom("BalooDa-Regular", size: Sizing.f(26)))
                    }
                    .accessibilityAddTraits(progress.noteLabelStyle == style ? .isSelected : [])
                }
            }
            caption("How notes are written on the keys and in songs.")
        }
    }

    private static func title(of style: NoteLabelStyle) -> LocalizedStringKey {
        switch style {
        case .notAngka: return "Not angka"
        case .solfege: return "Do Re Mi"
        case .letters: return "C D E"
        }
    }

    // MARK: Sound effects

    private var soundCard: some View {
        card("Sound effects") {
            Toggle(isOn: Binding(get: { progress.sfxEnabled }, set: { newValue in
                progress.sfxEnabled = newValue
                // A click when switching them on, so you can hear that it worked.
                if newValue { SFX.play(.button) }
            })) {
                Text("Sound effects on")
                    .font(Font.headline)
                    .foregroundColor(Color.darkGreen)
            }
            .tint(Color.darkGreen)
            caption("Hits, clicks and coins. The pianika notes always play.")
            Divider()
            Toggle(isOn: Binding(get: { progress.backingTrackEnabled }, set: { progress.backingTrackEnabled = $0 })) {
                Text("Backing music")
                    .font(Font.headline)
                    .foregroundColor(Color.darkGreen)
            }
            .tint(Color.darkGreen)
            caption("Plays the song's instrumental in the song stage. Off in Real pianika mode.")
        }
    }

    // MARK: Audio timing

    private var audioCard: some View {
        card("Audio timing") {
            HStack {
                Text(Self.offsetText(progress.audioOffsetMs))
                    .font(.custom("BalooDa-Regular", size: Sizing.f(34)))
                    .foregroundColor(Color.darkGreen)
                    .frame(width: Sizing.isPhone ? 96 : 130, alignment: .leading)
                Slider(value: Binding(get: { Double(progress.audioOffsetMs) },
                                      set: { progress.audioOffsetMs = Int($0.rounded()) }),
                       in: Double(AudioCalibration.offsetRange.lowerBound)...Double(AudioCalibration.offsetRange.upperBound),
                       step: 5)
                    .tint(Color.darkGreen)
                    .accessibilityLabel(Text("Audio timing"))
                    .accessibilityValue(Text(Self.offsetText(progress.audioOffsetMs)))
            }
            HStack(spacing: Sizing.s(14)) {
                SoundButton {
                    isCalibrating = true
                } label: {
                    Text("Tap to the beat")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, Sizing.s(28))
                        .frame(height: Sizing.tap(60))
                        .background(Color.yellow)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(Sizing.s(18))
                        .font(Font.headline)
                }
                SoundButton {
                    progress.audioOffsetMs = 0
                } label: {
                    Text("Reset")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, Sizing.s(28))
                        .frame(height: Sizing.tap(60))
                        .background(Color.softBlue.opacity(0.5))
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(Sizing.s(18))
                        .font(Font.headline)
                }
                .disabled(progress.audioOffsetMs == 0)
            }
            caption("Slide right if you always hit a little late, left if you hit early. Or let the game measure it for you.")
        }
    }

    /// "+40 ms", "−25 ms" or "0 ms".
    static func offsetText(_ ms: Int) -> String {
        ms > 0 ? "+\(ms) ms" : (ms < 0 ? "−\(-ms) ms" : "0 ms")
    }

    // MARK: Reset

    private var resetCard: some View {
        card("Reset progress") {
            SoundButton {
                isConfirmingReset = true
            } label: {
                Text("Reset progress")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, Sizing.s(28))
                    .frame(height: Sizing.tap(60))
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(Sizing.s(18))
                    .font(Font.headline)
            }
            if didReset {
                Label("Progress was reset", systemImage: "checkmark.circle.fill")
                    .font(Font.headline)
                    .foregroundColor(Color.darkGreen)
            }
            caption("Starts the game over: stars, coins, shop items, trophies and achievements. Your settings and what you bought with real money stay.")
        }
    }

    private func resetProgress() {
        progress.resetProgress()
        AchievementStore.shared.reload()
        didReset = true
    }

    // MARK: Account

    /// Optional Sign in with Apple, so progress and purchases follow the player to another device. Asks for no name and no
    /// e-mail. Hidden until the `accounts` flag is on.
    @ViewBuilder
    private var accountCard: some View {
        if FeatureFlags.isOn(.accounts) {
            card("Account") {
                if account.state == .linked {
                    Label("Signed in with Apple", systemImage: "checkmark.seal.fill")
                        .font(Font.headline)
                        .foregroundColor(Color.darkGreen)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = []
                    } onCompletion: { result in
                        handleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: Sizing.tap(56))
                }
                if let accountMessage {
                    Text(accountMessage).font(.subheadline).foregroundColor(Color.darkGreen)
                }
                caption("Optional. Keep your stars, coins and songs when you change devices. We don't ask for your name or e-mail.")
            }
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
            accountMessage = "Sign in did not work"
            return
        }
        Task {
            if await account.linkApple(identityToken: token) {
                accountMessage = nil
                await ProgressSyncService.shared.sync()
            } else {
                accountMessage = "Sign in did not work"
            }
        }
    }

    // MARK: Melodissimo Plus

    /// Subscription status with Manage and Restore. Hidden until the pack store is switched on (`packStore` flag).
    @ViewBuilder
    private var plusCard: some View {
        if FeatureFlags.isOn(.packStore) {
            card("Melodissimo Plus") {
                Text(Self.plusStatusText(entitlements.plusStatus))
                    .font(Font.headline)
                    .foregroundColor(Color.darkGreen)
                HStack(spacing: Sizing.isPhone ? 6 : 12) {
                    SoundButton {
                        Task { await StoreService.shared.manageSubscriptions() }
                    } label: {
                        Text("Manage subscription")
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .frame(height: Sizing.tap(60))
                            .background(Color.yellow)
                            .foregroundColor(Color.darkGreen)
                            .cornerRadius(Sizing.s(18))
                            .font(Font.headline)
                    }
                    SoundButton {
                        Task { await StoreService.shared.restore() }
                    } label: {
                        Text("Restore purchases")
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                            .frame(height: Sizing.tap(60))
                            .background(Color.softBlue.opacity(0.5))
                            .foregroundColor(Color.darkGreen)
                            .cornerRadius(Sizing.s(18))
                            .font(Font.headline)
                    }
                }
            }
        }
    }

    static func plusStatusText(_ status: PlusStatus) -> LocalizedStringKey {
        switch status {
        case .none: return "Not subscribed"
        case .active(let renews):
            guard let renews else { return "Plus is active" }
            return "Plus renews on \(renews.formatted(date: .abbreviated, time: .omitted))"
        case .gracePeriod: return "Plus is active, but a payment needs attention"
        case .expired: return "Plus has ended"
        }
    }

    // MARK: About

    private var aboutCard: some View {
        card("About") {
            Text("Melodissimo")
                .font(Font.headline)
                .foregroundColor(Color.darkGreen)
            Text("Product of Anoran Technology")
                .font(Font.subheadline)
                .foregroundColor(Color.darkGreen)
            Text("Version \(Self.versionText)")
                .font(.footnote)
                .foregroundColor(Color.darkGreen.opacity(0.75))
            Text("Song Backsounds: Mas Hans")
                .font(.footnote)
                .foregroundColor(Color.darkGreen.opacity(0.75))
            Text("Sound effects: Kenney.nl (CC0)")
                .font(.footnote)
                .foregroundColor(Color.darkGreen.opacity(0.75))
        }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
