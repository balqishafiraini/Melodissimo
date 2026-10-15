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

            VStack(spacing: Sizing.s(24)) {
                HStack(alignment: .center, spacing: Sizing.s(28)) {
                    AlpanicaView(mood: alpanicaMood, outfit: .equipped, hopTrigger: hop, height: Sizing.isPhone ? 96 : 200, keepsOutfit: true)
                        .frame(width: Sizing.isPhone ? 70 : 200)

                    // The words come first: on iPhone they get at least half of the card, and scroll if there are too many.
                    Group {
                        if Sizing.isPhone {
                            ViewThatFits(in: .vertical) {
                                lines
                                ScrollView(showsIndicators: false) { lines }
                            }
                        } else {
                            lines
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(Sizing.isPhone ? 1 : 0)

                    monster
                        .frame(width: Sizing.isPhone ? 80 : 200, height: Sizing.isPhone ? 96 : 210)
                }

                SoundButton(action: onContinue) {
                    Text("Continue")
                        .buttonFrame(width: 260, height: 64)
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(Sizing.s(20))
                        .font(Font.headline)
                }
            }
            .padding(Sizing.isPhone ? 18 : 36)
            .background(RoundedRectangle(cornerRadius: Sizing.s(36)).fill(Color.vanila))
            .padding(.horizontal, Sizing.isPhone ? 12 : 50)
            .padding(.vertical, Sizing.isPhone ? 8 : 0)
        }
        .onAppear {
            // Alpanica gives a little hop as the card opens.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { hop += 1 }
        }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: Sizing.s(14)) {
            ForEach(card.lines, id: \.self) { line in
                Text(LocalizedStringKey(line))
                    .font(.custom("BalooDa-Regular", size: Sizing.f(30)))
                    .foregroundColor(Color.darkGreen)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                    .font(.custom("BalooDa-Regular", size: Sizing.f(56)))
            }
        case .finale:
            Text("🇮🇩")
                .font(.custom("BalooDa-Regular", size: Sizing.f(120)))
        }
    }
}
