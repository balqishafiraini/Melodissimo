//
//  StageSheetView.swift
//  Melodissimo
//

import SwiftUI

/// What opens when a stage node is tapped: its name, kind, a line about what's in it, the best
/// stars and a Play button.
struct StageSheetView: View {
    let stage: Stage
    let stars: Int
    let onPlay: () -> Void
    /// Set for the finale once it has a star, so the certificate can be opened again.
    var onCertificate: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            AssetImage(name: stage.iconName, fallbackEmoji: stage.fallbackEmoji)
                .frame(width: 110, height: 110)

            VStack(spacing: 4) {
                Text(stage.title)
                    .font(.custom("BalooDa-Regular", size: 40))
                    .foregroundColor(Color.darkGreen)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 8) {
                    Text(stage.kindTitle)
                    detail
                }
                .font(.headline)
                .foregroundColor(Color.darkGreen.opacity(0.7))
            }

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < stars ? "star.fill" : "star")
                        .font(.custom("BalooDa-Regular", size: 38))
                        .foregroundColor(index < stars ? Color.yellow : Color.darkGreen.opacity(0.3))
                }
            }

            Button(action: onPlay) {
                Text("Play")
                    .frame(width: 240, height: 64)
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .font(Font.headline)
            }

            if let onCertificate {
                Button(action: onCertificate) {
                    Label("Certificate", systemImage: "rosette")
                        .font(Font.headline)
                        .foregroundColor(Color.darkGreen)
                }
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.vanila.ignoresSafeArea())
    }

    /// A short line about what is in the stage.
    @ViewBuilder
    private var detail: some View {
        switch stage.kind {
        case .battle(let config):
            Text("· \(config.totalQuestions) questions")
        case .echo(let config):
            Text("· \(config.roundsToClear ?? 0) rounds")
        case .song, .boss, .finale:
            if let song = stage.song {
                Text("· \(song.keyIds.count) notes")
            }
        }
    }
}
