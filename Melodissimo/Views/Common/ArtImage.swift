//
//  ArtImage.swift
//  Melodissimo
//

import SwiftUI
import UIKit

/// A picture from an `ArtSource`: an asset-catalog image or a downloaded file. A file that can't be read, or an
/// asset that is missing, falls back to an emoji like `AssetImage`.
struct ArtImage: View {
    let source: ArtSource
    var fallbackEmoji = "🦙"

    /// Decoded files, so a view body doesn't read from disk on every redraw.
    private static let cache = NSCache<NSURL, UIImage>()

    private static func image(at url: URL) -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    var body: some View {
        switch source {
        case .asset(let name):
            AssetImage(name: name, fallbackEmoji: fallbackEmoji)
        case .file(let url):
            if let image = Self.image(at: url) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                AssetImage(name: "", fallbackEmoji: fallbackEmoji)
            }
        }
    }
}
