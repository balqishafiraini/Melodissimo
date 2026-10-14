//
//  HubCard.swift
//  Melodissimo
//

import SwiftUI

/// A big rounded card with a badge, a title and a line of detail: the building block of the
/// hub screens (Free Play, Learn).
struct HubCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    /// Name of a badge in the asset catalog; a note emoji stands in if it is missing.
    let icon: String
    var color: Color = .green
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        SoundButton(action: action) {
            HStack(spacing: Sizing.s(20)) {
                AssetImage(name: icon, fallbackEmoji: "🎵")
                    .frame(width: Sizing.s(110), height: Sizing.s(110))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("BalooDa-Regular", size: Sizing.f(44)))
                        .lineLimit(Sizing.isPhone ? 1 : nil)
                        .minimumScaleFactor(Sizing.isPhone ? 0.7 : 1)
                    Text(subtitle)
                        .font(.headline)
                        .lineLimit(Sizing.isPhone ? 3 : nil)
                        .minimumScaleFactor(Sizing.isPhone ? 0.75 : 1)
                        .opacity(0.9)
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(Sizing.s(24))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: Sizing.s(36)).fill(isEnabled ? color : Color.gray))
            .opacity(isEnabled ? 1 : 0.7)
        }
        .disabled(!isEnabled)
    }
}
