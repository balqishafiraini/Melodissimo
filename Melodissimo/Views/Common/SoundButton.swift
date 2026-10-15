//
//  SoundButton.swift
//  Melodissimo
//

import SwiftUI

/// A `Button` that plays the click effect when it is tapped. It looks and behaves like `Button`, so
/// `SoundButton { … } label: { … }` is a drop-in replacement in the game's screens.
struct SoundButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            SFX.play(.button)
            action()
        } label: {
            label()
        }
    }
}
