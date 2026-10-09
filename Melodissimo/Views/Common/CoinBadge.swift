//
//  CoinBadge.swift
//  Melodissimo
//

import SwiftUI

/// The coin balance in a yellow capsule, for Home and the shop.
struct CoinBadge: View {
    @ObservedObject private var progress = ProgressStore.shared
    var height: CGFloat = 72

    var body: some View {
        HStack(spacing: 8) {
            AssetImage(name: "icon_coin", fallbackEmoji: "🪙")
                .frame(width: height * 0.53, height: height * 0.53)
            Text("\(progress.coinBalance)")
                .font(Font.headline)
                .foregroundColor(Color.darkGreen)
                .contentTransition(.numericText())
                .animation(.default, value: progress.coinBalance)
        }
        .padding(.horizontal, 20)
        .frame(height: height)
        .background(Capsule().fill(Color.yellow))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Coins"))
        .accessibilityValue(Text("\(progress.coinBalance)"))
    }
}

/// "+N" next to a coin that counts up from 0 when it appears, for the results screen. With Reduce
/// Motion on (or after `delay`) it simply shows the total.
struct CoinCountUp: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let total: Int
    /// Seconds to wait before counting, so the stars can land first.
    var delay: Double = 0.6

    @State private var shown = 0

    var body: some View {
        HStack(spacing: 8) {
            Text("+\(shown)")
                .font(.custom("BalooDa-Regular", size: 40))
                .foregroundColor(Color.darkGreen)
                .contentTransition(.numericText())
            AssetImage(name: "icon_coin", fallbackEmoji: "🪙")
                .frame(width: 40, height: 40)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Coins earned"))
        .accessibilityValue(Text("\(total)"))
        .onAppear(perform: count)
    }

    /// About 25 steps over a second or so, however many coins there are.
    private func count() {
        guard total > 0 else { return }
        guard !reduceMotion else {
            shown = total
            return
        }
        let steps = min(total, 25)
        for step in 1...steps {
            let value = Int((Double(total) * Double(step) / Double(steps)).rounded())
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.04 * Double(step)) {
                withAnimation(.easeOut(duration: 0.1)) { shown = value }
            }
        }
    }
}
