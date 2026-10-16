//
//  MaintenanceView.swift
//  Melodissimo
//

import SwiftUI

/// Full-screen maintenance notice, used only when the server says maintenance blocks play.
struct MaintenanceView: View {
    let info: Bootstrap.MaintenanceInfo

    var body: some View {
        ZStack {
            Color.softBlue.ignoresSafeArea()
            VStack(spacing: Sizing.s(18)) {
                AssetImage(name: "alpanica_sleepy", fallbackEmoji: "😴")
                    .frame(height: Sizing.isPhone ? 90 : 220)
                Text(info.title?.resolved().nonEmpty ?? NSLocalizedString("We'll be back soon", comment: ""))
                    .font(.custom("BalooDa-Regular", size: Sizing.f(44)))
                    .foregroundColor(Color.darkGreen)
                    .multilineTextAlignment(.center)
                if let message = info.message?.resolved().nonEmpty {
                    Text(message)
                        .font(.headline)
                        .foregroundColor(Color.darkGreen)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }
            }
            .padding(Sizing.s(30))
        }
    }
}

/// A slim notice on Home while maintenance is on but play still works.
struct MaintenanceBanner: View {
    let info: Bootstrap.MaintenanceInfo

    var body: some View {
        HStack(spacing: Sizing.s(10)) {
            Image(systemName: "wrench.and.screwdriver.fill")
            Text(info.title?.resolved().nonEmpty ?? NSLocalizedString("Maintenance", comment: ""))
                .font(.subheadline.bold())
            if let message = info.message?.resolved().nonEmpty {
                Text(message).font(.subheadline).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundColor(Color.darkGreen)
        .padding(.horizontal, Sizing.s(16))
        .frame(height: Sizing.tap(44))
        .background(Capsule().fill(Color.yellow))
        .accessibilityElement(children: .combine)
    }
}

private extension String {
    /// `nil` for an empty or blank string, so a server text with nothing in it falls back to the built-in one.
    var nonEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
