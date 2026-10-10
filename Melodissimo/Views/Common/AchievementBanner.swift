//
//  AchievementBanner.swift
//  Melodissimo
//

import SwiftUI

/// "Achievement unlocked!" with the titles of the badges just earned, for the results screen and the shop.
struct AchievementBanner: View {
    let titles: [String]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundColor(Color.yellow)
            VStack(alignment: .leading, spacing: 0) {
                Text("Achievement unlocked!")
                    .font(.caption)
                    .opacity(0.85)
                Text(titles.joined(separator: " · "))
                    .font(.custom("BalooDa-Regular", size: 24))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.darkGreen))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
    }
}
