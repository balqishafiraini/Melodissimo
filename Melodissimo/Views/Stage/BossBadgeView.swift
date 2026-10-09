//
//  BossBadgeView.swift
//  Melodissimo
//

import SwiftUI

/// The Fals boss in a boss stage's top bar: its art, shaking and flashing on every hit, and (while
/// performing) a health bar that empties as notes are hit. A notch marks the health at which the
/// boss counts as beaten.
struct BossBadgeView<Hit: Equatable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 1–6, the island the boss belongs to.
    var kind: Int
    /// 0...1, or `nil` to show the boss without a bar (Listen and Practice).
    var health: Double?
    var hitTrigger: Hit
    var height: CGFloat = 76

    private let barWidth: CGFloat = 190

    var body: some View {
        HStack(spacing: 12) {
            if let health {
                healthBar(fraction: health)
            }
            AssetImage(name: "fals_boss_\(kind)", fallbackEmoji: "🐲")
                .frame(width: height, height: height)
                .wobble(degrees: 4)
                .hitShake(on: hitTrigger)
        }
    }

    private func healthBar(fraction: Double) -> some View {
        let clamped = max(0, min(1, fraction))
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.35))
            Capsule()
                .fill(clamped > 0.6 ? Color.green : (clamped > BossHealth.defeatFraction ? Color.yellow : Color.red))
                .frame(width: barWidth * clamped)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: clamped)
            // Below this line the boss is beaten.
            Rectangle()
                .fill(Color.white)
                .frame(width: 3, height: 24)
                .offset(x: barWidth * BossHealth.defeatFraction - 1.5)
        }
        .frame(width: barWidth, height: 16)
        .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 2))
        .accessibilityElement()
        .accessibilityLabel(Text("Boss health"))
        .accessibilityValue(Text("\(Int((clamped * 100).rounded())) %"))
    }
}
