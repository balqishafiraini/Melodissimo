//
//  ContinueSheet.swift
//  Melodissimo
//

import SwiftUI

/// "Lanjut?": shown when the hearts run out and a revive is on offer. Offers the ways to continue and Give up; doing
/// nothing for `timeout` seconds counts as giving up. The game behind it is paused (its phase is `awaitingContinue`).
struct ContinueSheet: View {
    let options: [ReviveOption]
    var timeout = 10
    let onRevive: (ReviveSource) -> Void
    let onGiveUp: () -> Void
    /// The coin option was tapped without enough coins: the host opens the shop to buy more, then shows the sheet again.
    let onNeedCoins: () -> Void

    @State private var secondsLeft = 10

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: Sizing.s(16)) {
                Image(systemName: "heart.fill")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(90)))
                    .foregroundColor(Color(red: 0.84, green: 0.05, blue: 0.2))
                Text("Continue?")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(48)))
                    .foregroundColor(Color.darkGreen)

                ForEach(options, id: \.source) { option in
                    optionButton(option)
                }

                SoundButton {
                    onGiveUp()
                } label: {
                    Text("Give up")
                        .frame(maxWidth: .infinity)
                        .frame(height: Sizing.tap(56))
                        .foregroundColor(Color.darkGreen)
                        .font(.headline)
                }

                Text("\(secondsLeft)")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(26)))
                    .foregroundColor(Color.darkGreen.opacity(0.6))
            }
            .padding(Sizing.s(28))
            .frame(width: Sizing.isPhone ? 300 : 420)
            .background(RoundedRectangle(cornerRadius: Sizing.s(32)).fill(Color.white))
        }
        .task {
            secondsLeft = timeout
            while secondsLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                secondsLeft -= 1
            }
            onGiveUp()
        }
    }

    @ViewBuilder
    private func optionButton(_ option: ReviveOption) -> some View {
        SoundButton {
            if option.isAffordable { onRevive(option.source) } else { onNeedCoins() }
        } label: {
            HStack(spacing: Sizing.s(8)) {
                switch option.source {
                case .plus:
                    Text("Free revive (Plus)")
                case .heart:
                    Image(systemName: "heart.fill")
                    Text("Use 1 heart")
                case .coins:
                    AssetImage(name: "icon_coin", fallbackEmoji: "🪙")
                        .frame(width: Sizing.s(30), height: Sizing.s(30))
                    Text(option.isAffordable ? "Pay \(option.cost) coins" : "Get coins")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Sizing.tap(60))
            .background(option.source == .coins ? Color.yellow : Color.darkGreen)
            .foregroundColor(option.source == .coins ? Color.darkGreen : .white)
            .cornerRadius(Sizing.s(18))
            .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
        }
    }
}
