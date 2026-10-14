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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if Sizing.isPhone { phoneBody } else { ipadBody }
    }

    /// iPhone: the badge on the left, everything else in a column on the right, with a close button. The sheet is
    /// about 340 pt tall in landscape, and the iPad's stacked layout needs more than that.
    private var phoneBody: some View {
        HStack(spacing: 28) {
            AssetImage(name: stage.iconName, fallbackEmoji: stage.fallbackEmoji)
                .frame(width: 110, height: 110)

            VStack(spacing: 8) {
                Text(stage.title)
                    .font(.custom("BalooDa-Regular", size: 30))
                    .foregroundColor(Color.darkGreen)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    Text(stage.kindTitle)
                    detail
                }
                .font(.headline)
                .foregroundColor(Color.darkGreen.opacity(0.7))

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.custom("BalooDa-Regular", size: 28))
                            .foregroundColor(index < stars ? Color.yellow : Color.darkGreen.opacity(0.3))
                    }
                }

                SoundButton(action: onPlay) {
                    Text("Play")
                        .frame(maxWidth: 240, minHeight: 48)
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .font(Font.headline)
                }

                if let onCertificate {
                    SoundButton(action: onCertificate) {
                        Label("Certificate", systemImage: "rosette")
                            .font(Font.headline)
                            .foregroundColor(Color.darkGreen)
                            .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 300)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.vanila.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            // A sheet on iPhone is closed by swiping down; a visible button says so.
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.custom("BalooDa-Regular", size: 30))
                    .foregroundColor(Color.darkGreen.opacity(0.45))
                    .frame(width: 44, height: 44)
            }
            .padding(8)
            .accessibilityLabel(Text("Close"))
        }
    }

    /// iPad: the v2 layout, unchanged.
    private var ipadBody: some View {
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

            SoundButton(action: onPlay) {
                Text("Play")
                    .frame(width: 240, height: 64)
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .font(Font.headline)
            }

            if let onCertificate {
                SoundButton(action: onCertificate) {
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
