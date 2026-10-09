//
//  AssetImage.swift
//  Melodissimo
//

import SwiftUI

/// An image from the asset catalog that falls back to an emoji when the asset is missing, so a
/// screen never shows a hole where art hasn't been added yet. Drop an asset in with the same name
/// and it replaces the emoji automatically.
struct AssetImage: View {
    let name: String
    let fallbackEmoji: String

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            GeometryReader { geo in
                Text(fallbackEmoji)
                    .font(.custom("BalooDa-Regular", size: min(geo.size.width, geo.size.height) * 0.8))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
