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

                centerContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                PianoKeyboard(metrics: .stage,
                              showLabels: true,
                              playsSound: false,
                              pressedFromOutside: mic.currentKeyId.map { [$0] } ?? [])
            }
            .ignoresSafeArea(edges: Sizing.isPhone ? [] : .bottom)
        }
        .onAppear { mic.start() }
        .onDisappear { mic.stop() }
    }

    /// The title, the note to play, the circle that lights when it is heard, and the status line. The iPad stacks
    /// them; the iPhone has too little height for that, so the circle sits beside the text.
    @ViewBuilder
    private var centerContent: some View {
        if Sizing.isPhone {
            HStack(spacing: 24) {
                heardCircle
                VStack(spacing: 4) {
                    title
                    prompt
                    statusText
                }
            }
            .padding(.horizontal, 24)
        } else {
            VStack(spacing: 18) {
                title
                prompt
                heardCircle
                statusText
            }
        }
    }

    private var title: some View {
        Text("Test the microphone")
            .font(.custom("BalooDa-Regular", size: Sizing.f(44)))
            .foregroundColor(.white)
    }

    private var prompt: some View {
        Text("Play 1 (C) on your pianika")
            .font(Font.title2)
            .foregroundColor(.white.opacity(0.85))
    }

    private var heardCircle: some View {
        ZStack {
            Circle()
                .fill(heardTarget ? Color.green : Color.white.opacity(0.15))
                .frame(width: Sizing.isPhone ? 100 : 190, height: Sizing.isPhone ? 100 : 190)
            Text(heardLabel ?? "…")
                .font(.custom("BalooDa-Regular", size: Sizing.isPhone ? 44 : 80))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch mic.status {
        case .denied:
            Text("Microphone access is off. Turn it on in your device's Settings to play with a real pianika.")
                .multilineTextAlignment(.center)
                .foregroundColor(.yellow)
                .padding(.horizontal, Sizing.s(60))
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
