//
//  StageSetupView.swift
//  Melodissimo
//

import SwiftUI

/// Before a song stage: pick how to play it (Listen, Practice, Perform), the speed, and whether the
/// keys show their note names. Perform stays locked until the song has been practiced once.
struct StageSetupView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared

    let song: Song
    /// Set when the stage comes from the campaign map, so the result routes back to it.
    var campaignStageId: String? = nil
    var isBoss = false

    @State private var speed = 1.0
    @State private var showLabels = true
    /// Until the player flips the toggle, Perform follows the "labels in Perform" setting instead.
    @State private var labelsTouched = false

    private static let speeds: [(value: Double, title: String)] = [(0.5, "0.5×"), (0.75, "0.75×"), (1, "1×")]

    private var isPracticed: Bool { progress.isSongPracticed(song.id) }

    var body: some View {
        if Sizing.isPhone { phoneBody } else { ipadBody }
    }

    /// iPad: the v2 layout, unchanged.
    private var ipadBody: some View {
        ZStack {
            Rectangle()
                .fill(Color.softBlue)
                .ignoresSafeArea()
            Image("bgMusic")
                .scaledToFit()

            VStack(spacing: 16) {
                topBar

                HStack(alignment: .top, spacing: 32) {
                    notationCard
                    VStack(alignment: .leading, spacing: 20) {
                        statsRow
                        speedPicker
                        labelsToggle
                        Spacer(minLength: 0)
                        modeButtons
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .padding(.top)
        }
    }

    /// iPhone: the score sheet on the left and the controls in a compact column on the right, so everything fits in
    /// 340 pt without scrolling (the column scrolls only if a very long translation needs more room).
    private var phoneBody: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue)

            VStack(spacing: 6) {
                phoneTopBar

                HStack(alignment: .top, spacing: 12) {
                    NotAngkaSheetView(chart: SongChart.load(for: song))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))

                    ViewThatFits(in: .vertical) {
                        phoneControls
                        ScrollView(showsIndicators: false) { phoneControls }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
    }

    private var phoneTopBar: some View {
        HStack {
            SoundButton {
                router.pop()
            } label: {
                Text("< Back")
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(minWidth: 88, minHeight: 44, maxHeight: 44)
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .font(Font.headline)
            }
            Spacer()
            Text(song.title)
                .font(.custom("BalooDa-Regular", size: 24))
                .foregroundColor(Color.darkGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            // Keeps the title centred.
            Color.clear.frame(width: 88, height: 44)
        }
        .padding(.horizontal, 10)
    }

    private var phoneControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            statsRow

            HStack(spacing: 8) {
                Text("Speed")
                    .font(.headline)
                    .foregroundColor(Color.darkGreen)
                    // "Kecepatan" in Indonesian: it keeps its width and shrinks before it wraps.
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .layoutPriority(1)
                ForEach(Self.speeds, id: \.value) { option in
                    SoundButton {
                        speed = option.value
                    } label: {
                        Text(option.title)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(speed == option.value ? Color.darkGreen : Color.white)
                            .foregroundColor(speed == option.value ? .white : Color.darkGreen)
                            .cornerRadius(12)
                            .font(.custom("BalooDa-Regular", size: 18))
                    }
                }
            }
            Text("Slower speeds earn fewer stars")
                .font(.footnote)
                .foregroundColor(Color.darkGreen.opacity(0.8))
            if let campaignStageId, progress.stageStars(campaignStageId) == 0 {
                Label("Perform with at least 60% accuracy (1★) to open the next stage", systemImage: "lock.open.fill")
                    .font(.footnote.bold())
                    .foregroundColor(Color.darkGreen)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(isOn: Binding(get: { showLabels }, set: { showLabels = $0; labelsTouched = true })) {
                Text("Show key labels")
                    .font(.headline)
                    .foregroundColor(Color.darkGreen)
            }
            .tint(Color.darkGreen)

            HStack(spacing: 8) {
                phoneModeButton(.listen, title: "Listen", symbol: "ear.fill", color: Color.softGreen)
                phoneModeButton(.practice, title: "Practice", symbol: "hand.tap.fill", color: Color.yellow)
                phoneModeButton(.perform, title: "Perform", symbol: "star.fill", color: Color.red, locked: !isPracticed)
            }
            if !isPracticed {
                Label("Finish Practice once to unlock Perform", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundColor(Color.darkGreen)
            }
        }
    }

    private func phoneModeButton(_ mode: StageMode, title: LocalizedStringKey, symbol: String, color: Color, locked: Bool = false) -> some View {
        SoundButton {
            start(mode)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: locked ? "lock.fill" : symbol)
                    .font(.custom("BalooDa-Regular", size: 22))
                Text(title)
                    .font(.custom("BalooDa-Regular", size: 16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 14).fill(locked ? Color.gray.opacity(0.45) : color))
            .foregroundColor(locked ? Color.darkGreen.opacity(0.5) : Color.darkGreen)
        }
        .disabled(locked)
    }

    // MARK: Pieces

    private var topBar: some View {
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

            Text(song.title)
                .font(.custom("BalooDa-Regular", size: 44))
                .foregroundColor(Color.darkGreen)
                .lineLimit(1)

            Spacer()

            // Keeps the title centred.
            Color.clear.frame(width: 120, height: 80)
        }
        .padding(.horizontal, 32)
    }

    private var notationCard: some View {
        NotAngkaSheetView(chart: SongChart.load(for: song))
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 30).fill(Color.white))
    }

    private var statsRow: some View {
        HStack(spacing: Sizing.s(24)) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < progress.songStars(song.id) ? "star.fill" : "star")
                        .foregroundColor(index < progress.songStars(song.id) ? Color.yellow : Color.darkGreen.opacity(0.4))
                        .font(.title)
                }
            }

            if progress.songBestAccuracy(song.id) > 0 {
                HStack(spacing: 6) {
                    Text("Best").lineLimit(1)
                    Text("\(Int(progress.songBestAccuracy(song.id).rounded()))%")
                        .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
                }
                .foregroundColor(Color.darkGreen)
            }

            if isPracticed {
                Label("Practiced", systemImage: "checkmark.circle.fill")
                    .foregroundColor(Color.darkGreen)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    // On a phone the tick says it; the word has no room next to the stars and the best score.
                    .labelStyle(PracticedLabelStyle())
            }
            Spacer()
        }
    }

    private var speedPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Speed")
                .font(.headline)
                .foregroundColor(Color.darkGreen)
            HStack(spacing: 12) {
                ForEach(Self.speeds, id: \.value) { option in
                    SoundButton {
                        speed = option.value
                    } label: {
                        Text(option.title)
                            .frame(width: 110, height: 52)
                            .background(speed == option.value ? Color.darkGreen : Color.white)
                            .foregroundColor(speed == option.value ? .white : Color.darkGreen)
                            .cornerRadius(16)
                            .font(.custom("BalooDa-Regular", size: 24))
                    }
                }
            }
            Text("Slower speeds earn fewer stars")
                .font(.footnote)
                .foregroundColor(Color.darkGreen.opacity(0.8))
            // A map stage stays locked until this one has a star, so say what that takes.
            if let campaignStageId, progress.stageStars(campaignStageId) == 0 {
                Label("Perform with at least 60% accuracy (1★) to open the next stage",
                      systemImage: "lock.open.fill")
                    .font(.footnote.bold())
                    .foregroundColor(Color.darkGreen)
            }
        }
    }

    private var labelsToggle: some View {
        Toggle(isOn: Binding(get: { showLabels }, set: { showLabels = $0; labelsTouched = true })) {
            Text("Show key labels")
                .font(.headline)
                .foregroundColor(Color.darkGreen)
        }
        .tint(Color.darkGreen)
        .frame(maxWidth: 360)
    }

    private var modeButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                modeButton(.listen, title: "Listen", symbol: "ear.fill", color: Color.softGreen)
                modeButton(.practice, title: "Practice", symbol: "hand.tap.fill", color: Color.yellow)
                modeButton(.perform, title: "Perform", symbol: "star.fill", color: Color.red, locked: !isPracticed)
            }
            if !isPracticed {
                Label("Finish Practice once to unlock Perform", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundColor(Color.darkGreen)
            }
        }
    }

    private func modeButton(_ mode: StageMode, title: LocalizedStringKey, symbol: String, color: Color, locked: Bool = false) -> some View {
        SoundButton {
            start(mode)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: locked ? "lock.fill" : symbol)
                    .font(.custom("BalooDa-Regular", size: 40))
                Text(title)
                    .font(.custom("BalooDa-Regular", size: 30))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(RoundedRectangle(cornerRadius: 24).fill(locked ? Color.gray.opacity(0.45) : color))
            .foregroundColor(locked ? Color.darkGreen.opacity(0.5) : Color.darkGreen)
        }
        .disabled(locked)
    }

    // MARK: Start

    private func start(_ mode: StageMode) {
        // Perform follows the "labels in Perform" setting unless the player flipped the toggle.
        let labels: Bool? = (mode == .perform && !labelsTouched) ? nil : showLabels
        let request = PlayRequest(
            kind: .song(songId: song.id, mode: mode, speed: speed, isBoss: isBoss, isSolemn: song.isSolemn, noteLimit: nil),
            campaignStageId: campaignStageId,
            showKeyLabels: labels)
        router.push(.play(request))
    }
}

/// "✓ Practiced" in full on iPad; on iPhone only the tick (the label stays for VoiceOver).
private struct PracticedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        if Sizing.isPhone {
            configuration.icon
        } else {
            Label(configuration)
        }
    }
}
