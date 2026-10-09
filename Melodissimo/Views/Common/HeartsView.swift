//
//  HeartsView.swift
//  Melodissimo
//

import SwiftUI

/// Hearts left out of the maximum: full red hearts, then empty outlines.
struct HeartsView: View {
    let hearts: Int
    var maxHearts = 3
    var size: CGFloat = 36

    /// A saturated red, deeper than the app's `red` so a heart stays distinct on the red battle background.
    private static let heartRed = Color(red: 0.84, green: 0.05, blue: 0.2)

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<maxHearts, id: \.self) { index in
                // A white ring behind each heart keeps it readable on the red battle background.
                ZStack {
                    Image(systemName: "heart.fill")
                        .font(.custom("BalooDa-Regular", size: size + 8))
                        .foregroundColor(.white)
                    Image(systemName: "heart.fill")
                        .font(.custom("BalooDa-Regular", size: size))
                        .foregroundColor(index < hearts ? Self.heartRed : Color.black.opacity(0.25))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(hearts)"))
    }
}
