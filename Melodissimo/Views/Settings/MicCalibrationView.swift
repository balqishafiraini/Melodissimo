//
//  MicCalibrationView.swift
//  Melodissimo
//

import SwiftUI

/// "Play 1 (C)": the player blows a note on a real pianika and sees which key the microphone heard,
/// live, so they can find a good distance and volume before playing a song.
struct MicCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mic = MicrophoneInput()

    private var heardLabel: String? {
        mic.currentKeyId.map { NoteCatalog.note($0).label }
    }

    private var heardTarget: Bool { mic.currentKeyId == Self.targetKeyId }

    /// The key to play: 1 (C), which is key id 5.
    private static let targetKeyId = 5

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
                    Text("Test the microphone")
                        .font(.custom("BalooDa-Regular", size: 44))
                        .foregroundColor(.white)
                    Text("Play 1 (C) on your pianika")
                        .font(Font.title2)
                        .foregroundColor(.white.opacity(0.85))
                    ZStack {
                        Circle()
                            .fill(heardTarget ? Color.green : Color.white.opacity(0.15))
                            .frame(width: 190, height: 190)
                        Text(heardLabel ?? "…")
                            .font(.custom("BalooDa-Regular", size: 80))
                            .foregroundColor(.white)
                    }
                    statusText
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PianoKeyboard(metrics: .stage,
                              showLabels: true,
                              playsSound: false,
                              pressedFromOutside: mic.currentKeyId.map { [$0] } ?? [])
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear { mic.start() }
        .onDisappear { mic.stop() }
    }

    @ViewBuilder
    private var statusText: some View {
        switch mic.status {
        case .denied:
            Text("Microphone access is off. Turn it on in your device's Settings to play with a real pianika.")
                .multilineTextAlignment(.center)
                .foregroundColor(.yellow)
                .padding(.horizontal, 60)
        case .failed:
            Text("The microphone could not start.")
                .foregroundColor(.yellow)
        default:
            Text(heardTarget ? "Perfect! The game hears you." : "Hold the note steady for a moment.")
                .font(Font.headline)
                .foregroundColor(.white)
        }
    }
}
