//
//  StoryCardView.swift
//  Melodissimo
//

import SwiftUI

/// A few lines of story over a dimmed map: Alpanica on the left, the words in the middle and the
/// chapter's Fals on the right, with a Continue button.
struct StoryCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let card: StoryCard
    let onContinue: () -> Void

    @State private var hop = 0

    private var alpanicaMood: AlpanicaMood {
        card.kind == .bossDefeated ? .happy : .idle
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack(alignment: .center, spacing: 28) {
                    AlpanicaView(mood: alpanicaMood, hopTrigger: hop, height: 200)
                        .frame(width: 200)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(card.lines, id: \.self) { line in
                            Text(LocalizedStringKey(line))
                                .font(.custom("BalooDa-Regular", size: 30))
                                .foregroundColor(Color.darkGreen)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    monster
                        .frame(width: 200, height: 210)
                }

                Button(action: onContinue) {
                    Text("Continue")
                        .frame(width: 260, height: 64)
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .font(Font.headline)
                }
            }
            .padding(36)
            .background(RoundedRectangle(cornerRadius: 36).fill(Color.vanila))
            .padding(.horizontal, 50)
        }
        .onAppear {
            // Alpanica gives a little hop as the card opens.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { hop += 1 }
        }
    }

    /// Fals for an island's cards (with stars circling its head once it is beaten); the flag for the anthem.
    @ViewBuilder
    private var monster: some View {
        switch card.kind {
        case .chapterIntro:
            AssetImage(name: "fals_boss_\(card.chapter)", fallbackEmoji: "🐲")
                .wobble(degrees: 4)
        case .bossDefeated:
            ZStack(alignment: .top) {
                AssetImage(name: "fals_boss_\(card.chapter)", fallbackEmoji: "🐲")
                    .opacity(0.85)
                    .rotationEffect(.degrees(-12))
                Text("💫")
                    .font(.custom("BalooDa-Regular", size: 56))
            }
        case .finale:
            Text("🇮🇩")
                .font(.custom("BalooDa-Regular", size: 120))
        }
    }
}
