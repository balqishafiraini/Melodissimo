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
                            .frame(width: 120, height: 60)
                            .background(Color.yellow)
                            .foregroundColor(Color.darkGreen)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)

                VStack(spacing: 18) {
                    Text("Tap to the beat")
                        .font(.custom("BalooDa-Regular", size: 44))
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
            .ignoresSafeArea(edges: .bottom)
        }
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
            VStack(spacing: 16) {
                Text("Listen to the clicks and tap any key on every click.")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.9))
                Button {
                    model.start(now: CACurrentMediaTime())
                } label: {
                    Text("Start")
                        .frame(width: 220, height: 70)
                        .background(Color.yellow)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(24)
                        .font(.custom("BalooDa-Regular", size: 34))
                }
            }
        case .running:
            Circle()
                .fill(Color.yellow)
                .frame(width: 130, height: 130)
                .opacity(flash ? 1 : 0.25)
                .accessibilityHidden(true)
        case .finished:
            result
        }
    }

    private var dots: some View {
        HStack(spacing: 12) {
            ForEach(0..<AudioCalibration.beatCount, id: \.self) { index in
                Circle()
                    .fill(index < model.beatsPlayed ? Color.yellow : Color.white.opacity(0.25))
                    .frame(width: 18, height: 18)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var result: some View {
        VStack(spacing: 14) {
            if let suggestion = model.suggestion {
                if suggestion == 0 {
                    Text("Right on the beat!")
                } else if suggestion > 0 {
                    Text("You tap about \(suggestion) ms late")
                } else {
                    Text("You tap about \(-suggestion) ms early")
                }
                HStack(spacing: 14) {
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
        .font(.custom("BalooDa-Regular", size: 32))
        .foregroundColor(.white)
    }

    private func actionLabel(_ text: Text, filled: Bool) -> some View {
        text
            .padding(.horizontal, 28)
            .frame(height: 64)
            .background(filled ? Color.yellow : Color.white.opacity(0.2))
            .foregroundColor(filled ? Color.darkGreen : .white)
            .cornerRadius(20)
            .font(Font.headline)
    }
}
