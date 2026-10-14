//
//  SettingsView.swift
//  Melodissimo
//

import SwiftUI

/// How the game plays and feels: how fast notes fall, key labels, audio timing, and a reset. The
/// settings are plain `ProgressStore` values, so every screen picks them up the next time it opens.
struct SettingsView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared

    @State private var isCalibrating = false
    @State private var isTestingMicrophone = false
    @State private var isConfirmingReset = false
    @State private var isReallyConfirmingReset = false
    @State private var didReset = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.softBlue)
                .ignoresSafeArea()
            Image("bgMusic")
                .scaledToFit()

            VStack(spacing: 18) {
                topBar
                ScrollView {
                    VStack(spacing: 20) {
                        noteSpeedCard
                        inputCard
                        labelsCard
                        soundCard
                        audioCard
                        resetCard
                        aboutCard
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(30)
        }
        .fullScreenCover(isPresented: $isCalibrating) {
            CalibrationView()
        }
        .fullScreenCover(isPresented: $isTestingMicrophone) {
            MicCalibrationView()
        }
        .alert("Reset progress?", isPresented: $isConfirmingReset) {
            Button("Continue", role: .destructive) { isReallyConfirmingReset = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your stars, coins, purchases and trophies will be erased.")
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
                        .frame(minWidth: 120, minHeight: 80, maxHeight: 80)
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .font(Font.headline)
                }
                Spacer()
            }
        }
    }

    private func card<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.custom("BalooDa-Regular", size: 30))
                .foregroundColor(Color.darkGreen)
            content()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28).fill(Color.white))
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(Color.darkGreen.opacity(0.75))
    }

    // MARK: Note speed

    private var noteSpeedCard: some View {
        card("Note speed") {
            HStack(spacing: 12) {
                ForEach(ProgressStore.approachTimeChoices, id: \.self) { seconds in
                    SoundButton {
                        progress.approachTime = seconds
                    } label: {
                        Text(String(format: "%.1f s", seconds))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(progress.approachTime == seconds ? Color.darkGreen : Color.softBlue.opacity(0.5))
                            .foregroundColor(progress.approachTime == seconds ? .white : Color.darkGreen)
                            .cornerRadius(18)
                            .font(.custom("BalooDa-Regular", size: 26))
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
            HStack(spacing: 12) {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    SoundButton {
                        progress.inputMode = mode
                    } label: {
                        Text(mode == .touch ? "Touch" : "Real pianika")
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(progress.inputMode == mode ? Color.darkGreen : Color.softBlue.opacity(0.5))
                            .foregroundColor(progress.inputMode == mode ? .white : Color.darkGreen)
                            .cornerRadius(18)
                            .font(.custom("BalooDa-Regular", size: 26))
                    }
                    .accessibilityAddTraits(progress.inputMode == mode ? .isSelected : [])
                }
            }
            if progress.inputMode == .pianika {
                SoundButton {
                    isTestingMicrophone = true
                } label: {
                    Text("Test the microphone")
                        .padding(.horizontal, 28)
                        .frame(height: 60)
                        .background(Color.yellow)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(18)
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
                    .font(.custom("BalooDa-Regular", size: 34))
                    .foregroundColor(Color.darkGreen)
                    .frame(width: 130, alignment: .leading)
                Slider(value: Binding(get: { Double(progress.audioOffsetMs) },
                                      set: { progress.audioOffsetMs = Int($0.rounded()) }),
                       in: Double(AudioCalibration.offsetRange.lowerBound)...Double(AudioCalibration.offsetRange.upperBound),
                       step: 5)
                    .tint(Color.darkGreen)
                    .accessibilityLabel(Text("Audio timing"))
                    .accessibilityValue(Text(Self.offsetText(progress.audioOffsetMs)))
            }
            HStack(spacing: 14) {
                SoundButton {
                    isCalibrating = true
                } label: {
                    Text("Tap to the beat")
                        .padding(.horizontal, 28)
                        .frame(height: 60)
                        .background(Color.yellow)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(18)
                        .font(Font.headline)
                }
                SoundButton {
                    progress.audioOffsetMs = 0
                } label: {
                    Text("Reset")
                        .padding(.horizontal, 28)
                        .frame(height: 60)
                        .background(Color.softBlue.opacity(0.5))
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(18)
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
                    .padding(.horizontal, 28)
                    .frame(height: 60)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(18)
                    .font(Font.headline)
            }
            if didReset {
                Label("Progress was reset", systemImage: "checkmark.circle.fill")
                    .font(Font.headline)
                    .foregroundColor(Color.darkGreen)
            }
            caption("Starts the game over: stars, coins, shop items, trophies and achievements. Your settings stay.")
        }
    }

    private func resetProgress() {
        progress.resetProgress()
        AchievementStore.shared.reload()
        didReset = true
    }

    // MARK: About

    private var aboutCard: some View {
        card("About") {
            Text("Melodissimo · Konser Nusantara")
                .font(Font.headline)
                .foregroundColor(Color.darkGreen)
            Text("Version \(Self.versionText)")
                .font(.subheadline)
                .foregroundColor(Color.darkGreen.opacity(0.75))
            Text("Sound effects: Kenney.nl (CC0)")
                .font(.subheadline)
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
