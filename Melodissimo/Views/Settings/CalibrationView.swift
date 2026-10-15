//
//  CalibrationView.swift
//  Melodissimo
//

import SwiftUI

/// "Tap to the beat": eight clicks, the player taps any key along with them, and the average lateness
/// of the taps is offered as the audio offset. It uses the real keyboard, so the touch path measured
/// is the one the song stage uses.
struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var progress = ProgressStore.shared
    @StateObject private var model = CalibrationViewModel()

    @State private var ticker: DisplayLinkTicker?
    /// Set on every beat, so the circle flashes and fades.
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.navy.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .buttonFrame(width: 120, height: 60)
                            .background(Color.yellow)
                            .foregroundColor(Color.darkGreen)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.headline)
                    }
                    Spacer()
                }
                .padding(.horizontal, Sizing.s(30))
                .padding(.top, Sizing.s(20))

                VStack(spacing: Sizing.s(18)) {
                    Text("Tap to the beat")
                        .font(.custom("BalooDa-Regular", size: Sizing.f(44)))
                        .foregroundColor(.white)
                    centerPiece
                    dots
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PianoKeyboard(metrics: .stage,
                              showLabels: false,
                              playsSound: false,
                              onNoteOn: { _ in model.tap(now: CACurrentMediaTime()) })
            }
            .ignoresSafeArea(edges: Sizing.isPhone ? [] : .bottom)
        }
        .playScreen()
        .onAppear {
            model.onBeat = { _ in
                // The same sample path the song stage uses, so the click shares its audio latency.
                playSound(key: NoteCatalog.note(5).sound)
                flash = true
                withAnimation(.easeOut(duration: 0.3)) { flash = false }
            }
            let newTicker = DisplayLinkTicker { model.step(now: $0) }
            newTicker.start()
            ticker = newTicker
        }
        .onDisappear {
            ticker?.stop()
            ticker = nil
            stopAllSounds()
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var centerPiece: some View {
        switch model.phase {
        case .idle:
            VStack(spacing: Sizing.s(16)) {
                Text("Listen to the clicks and tap any key on every click.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Sizing.s(30))
                Button {
                    model.start(now: CACurrentMediaTime())
                } label: {
                    Text("Start")
                        .buttonFrame(width: 220, height: 70)
                        .background(Color.yellow)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(Sizing.s(24))
                        .font(.custom("BalooDa-Regular", size: Sizing.f(34)))
                }
            }
        case .running:
            Circle()
                .fill(Color.yellow)
                .frame(width: Sizing.s(130), height: Sizing.s(130))
                .opacity(flash ? 1 : 0.25)
                .accessibilityHidden(true)
        case .finished:
            result
        }
    }

    private var dots: some View {
        HStack(spacing: Sizing.s(12)) {
            ForEach(0..<AudioCalibration.beatCount, id: \.self) { index in
                Circle()
                    .fill(index < model.beatsPlayed ? Color.yellow : Color.white.opacity(0.25))
                    .frame(width: Sizing.s(18), height: Sizing.s(18))
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var result: some View {
        VStack(spacing: Sizing.s(14)) {
            if let suggestion = model.suggestion {
                if suggestion == 0 {
                    Text("Right on the beat!")
                } else if suggestion > 0 {
                    Text("You tap about \(suggestion) ms late")
                } else {
                    Text("You tap about \(-suggestion) ms early")
                }
                HStack(spacing: Sizing.s(14)) {
                    Button {
                        progress.audioOffsetMs = suggestion
                        dismiss()
                    } label: {
                        actionLabel(Text("Use \(SettingsView.offsetText(suggestion))"), filled: true)
                    }
                    Button {
                        model.reset()
                    } label: {
                        actionLabel(Text("Try again"), filled: false)
                    }
                }
            } else {
                Text("We didn't catch enough taps. Try again!")
                Button {
                    model.reset()
                } label: {
                    actionLabel(Text("Try again"), filled: true)
                }
            }
        }
        .font(.custom("BalooDa-Regular", size: Sizing.f(32)))
        .foregroundColor(.white)
    }

    private func actionLabel(_ text: Text, filled: Bool) -> some View {
        text
            .padding(.horizontal, Sizing.s(28))
            .frame(height: Sizing.tap(64))
            .background(filled ? Color.yellow : Color.white.opacity(0.2))
            .foregroundColor(filled ? Color.darkGreen : .white)
            .cornerRadius(Sizing.s(20))
            .font(Font.headline)
    }
}
