//
//  ArtSource.swift
//  Melodissimo
//

import Foundation

/// Where a picture comes from: an image in the asset catalog, or a file downloaded with a content release.
enum ArtSource: Hashable {
    case asset(String)
    case file(URL)

    /// Picks the source for one piece of art. Downloaded art wins once it is on disk; otherwise the bundled
    /// asset name is used. `nil` when the item has neither.
    static func resolve(bundled: String?, downloadedKey: String?, fileURL: (String) -> URL?) -> ArtSource? {
        if let key = downloadedKey, let url = fileURL(key) { return .file(url) }
        if let name = bundled, !name.isEmpty { return .asset(name) }
        return nil
    }
}

extension ShopItem {
    /// The picture of the item as shown in the shop and on the certificate.
    func previewArt(fileURL: (String) -> URL? = { _ in nil }) -> ArtSource? {
        ArtSource.resolve(bundled: bundledArt?.preview, downloadedKey: art?.preview, fileURL: fileURL)
    }

    /// The item alone on a clear canvas, laid over every pose (outfits).
    func overlayArt(fileURL: (String) -> URL? = { _ in nil }) -> ArtSource? {
        ArtSource.resolve(bundled: bundledArt?.overlay, downloadedKey: art?.overlay, fileURL: fileURL)
    }
}
