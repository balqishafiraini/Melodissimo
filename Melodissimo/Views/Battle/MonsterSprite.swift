//
//  MonsterSprite.swift
//  Melodissimo
//

import SwiftUI

/// A Fals monster for the Note Battle: wobbling art with a health bar. It flashes and shakes with a
/// floating "−1" when `hitTrigger` changes (a correct answer) and lunges at Alpanica when
/// `lungeTrigger` changes (a mistake). Everything is skipped under Reduce Motion.
struct MonsterSprite<Hit: Equatable, Lunge: Equatable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 1–3 for minions, 1–6 for the island bosses.
    var kind: Int
    var isBoss: Bool
    /// Remaining health and the maximum; `nil` hides the bar (endless Melody Rush).
    var health: (current: Int, maximum: Int)?
    var hitTrigger: Hit
    var lungeTrigger: Lunge
    var height: CGFloat = 280

    @State private var lunge: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            if let health, health.maximum > 0 {
                healthBar(current: health.current, maximum: health.maximum)
            }
            ZStack(alignment: .top) {
                AssetImage(name: isBoss ? "fals_boss_\(kind)" : "fals_minion_\(kind)",
                           fallbackEmoji: isBoss ? "🐲" : "👾")
                    .frame(height: height)
                    .wobble()
                    .hitShake(on: hitTrigger)
                FloatingText(text: "−1", trigger: hitTrigger)
            }
            .offset(x: lunge)
        }
        .onChange(of: lungeTrigger) { _ in
            guard !reduceMotion else { return }
            withAnimation(.easeIn(duration: 0.12)) { lunge = -90 }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.14)) { lunge = 0 }
        }
    }

    private func healthBar(current: Int, maximum: Int) -> some View {
        let fraction = max(0, min(1, Double(current) / Double(maximum)))
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.25))
            Capsule()
                .fill(fraction > 0.5 ? Color.green : (fraction > 0.25 ? Color.yellow : Color.red))
                .frame(width: 220 * fraction)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: current)
        }
        .frame(width: 220, height: 18)
        .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 2))
    }
}
