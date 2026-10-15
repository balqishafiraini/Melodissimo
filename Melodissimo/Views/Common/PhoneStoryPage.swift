//
//  PhoneStoryPage.swift
//  Melodissimo
//

import SwiftUI

/// The iPhone layout of the first-run pages (hello, scores, the post-play intro): cards and one big button in a
/// column on the left, Alpanica on the right, a "< Back" and a "?" button along the top. Everything respects the
/// safe area. If the column is taller than the screen it scrolls instead of being cut off.
///
/// The iPad versions of these pages keep their own, older layout; they are laid out for 820 pt of height.
struct PhoneStoryPage<Cards: View>: View {
    /// Asset name of the character art on the right.
    let art: String
    var buttonTitle: LocalizedStringKey?
    var onButton: () -> Void = {}
    var onHelp: (() -> Void)?
    var onBack: (() -> Void)?
    @ViewBuilder var cards: () -> Cards

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Text("< Back")
                            .buttonFrame(width: 120, height: 64)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.headline)
                    }
                }
                Spacer()
                if let onHelp {
                    Button(action: onHelp) {
                        Text("?")
                            .frame(width: Sizing.tap(80), height: Sizing.tap(80))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.title)
                    }
                }
            }
            .frame(height: Sizing.topBarButton)
            .padding(.top, Sizing.topBarInset)

            HStack(alignment: .bottom, spacing: 12) {
                ViewThatFits(in: .vertical) {
                    column
                    ScrollView(showsIndicators: false) { column }
                }
                .frame(maxWidth: .infinity)

                Image(art)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .padding(.horizontal, Sizing.topBarSide)
        .padding(.bottom, 8)
        // Pinned to the top, so the top bar sits where it does on every other screen even when the page is short.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A `NavigationView` nested in another (the score page's) keeps a hidden 44 pt bar's room at the top; the
        // landscape phone has no real top inset, so give it back and the top bar sits where it does everywhere else.
        .ignoresSafeArea(.container, edges: .top)
    }

    private var column: some View {
        VStack(spacing: 8) {
            cards()
            if let buttonTitle {
                Button(action: onButton) {
                    Text(buttonTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.yellow)
                        .foregroundColor(Color.red)
                        .cornerRadius(Sizing.s(20))
                        .font(Font.title)
                }
            }
        }
    }
}

extension View {
    /// A white rounded card of text on the first-run pages (iPhone).
    func phoneCard(alignment: TextAlignment = .leading) -> some View {
        self
            .font(.custom("BalooDa-Regular", size: 18))
            .lineSpacing(-4)
            .foregroundStyle(.black)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 22).fill(.white))
    }
}

/// The yellow circle with a quiz score in it, on the iPhone score pages.
struct PhoneScoreCircle: View {
    let score: Int
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.yellow)
                .frame(width: size, height: size)
            VStack(spacing: -4) {
                Text("Score:")
                    .font(.subheadline)
                Text("\(score)")
                    .font(.custom("BalooDa-Regular", size: size * 0.46))
            }
        }
    }
}
