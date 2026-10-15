//
//  ScreenBackdrop.swift
//  Melodissimo
//

import SwiftUI

/// A screen's flat colour with the music-note pattern (`bgMusic`) over it. On iPad it is exactly what the screens
/// always drew: the colour behind the safe area and the 1153 × 757 pt pattern at its natural size, centred. That
/// image is bigger than an iPhone's screen, so on iPhone it is fitted to the screen and clipped instead, which
/// also stops it from making the layout around it wider than the screen (`IPHONE_PLAN` D9).
struct ScreenBackdrop: View {
    var color: Color
    var imageName = "bgMusic"
    /// How the iPad version layers them, to match the screen it replaces: `true` draws the pattern as an overlay of
    /// the full-screen colour (centred on the whole screen), `false` as a sibling in a ZStack (centred in the safe area).
    var overlaysColor = false

    var body: some View {
        if Sizing.isPhone {
            // `ignoresSafeArea` last, so the clip happens on the full-screen frame (see SongStageView.background).
            color
                .overlay {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .ignoresSafeArea()
        } else if overlaysColor {
            color
                .ignoresSafeArea()
                .overlay {
                    Image(imageName)
                        .scaledToFit()
                }
        } else {
            ZStack {
                Rectangle()
                    .fill(color)
                    .ignoresSafeArea()
                Image(imageName)
                    .scaledToFit()
            }
        }
    }
}

/// The backdrop of the older screens (a flat colour and `bgMusic` as two layers). iPad draws them as it always did;
/// iPhone uses `ScreenBackdrop`, which fits the pattern to the screen.
struct LegacyBackdrop: View {
    var color: Color

    var body: some View {
        if Sizing.isPhone {
            ScreenBackdrop(color: color)
        } else {
            Rectangle()
                .fill(color)
                .scaledToFill()

            Image("bgMusic")
                .scaledToFit()
        }
    }
}
