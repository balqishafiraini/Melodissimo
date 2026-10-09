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

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                router.pop()
            } label: {
                Text("< Back")
                    .frame(width: 120, height: 80)
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
        Image(song.notationImage)
            .resizable()
            .scaledToFit()
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 30).fill(Color.white))
    }

    private var statsRow: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < progress.songStars(song.id) ? "star.fill" : "star")
                        .foregroundColor(index < progress.songStars(song.id) ? Color.yellow : Color.darkGreen.opacity(0.4))
                        .font(.title)
                }
            }

            if progress.songBestAccuracy(song.id) > 0 {
                HStack(spacing: 6) {
                    Text("Best")
                    Text("\(Int(progress.songBestAccuracy(song.id).rounded()))%")
                        .font(.custom("BalooDa-Regular", size: 28))
                }
                .foregroundColor(Color.darkGreen)
            }

            if isPracticed {
                Label("Practiced", systemImage: "checkmark.circle.fill")
                    .foregroundColor(Color.darkGreen)
                    .font(.headline)
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
                    Button {
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
        Button {
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
