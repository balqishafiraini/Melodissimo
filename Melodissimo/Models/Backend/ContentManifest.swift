//
//  ContentManifest.swift
//  Melodissimo
//
//  Codable mirror of `contracts/schema/manifest.schema.json` (`BACKEND_PLAN.md` §4.3). Unknown fields are ignored,
//  and an entry that doesn't decode (an unknown status, a broken field) is skipped without taking the rest down.
//

import Foundation

/// Country targeting for songs, packs, shop items and products (§4.10). No `include` means worldwide.
struct Markets: Codable, Hashable {
    var include: [String]?
    var exclude: [String]?
    var featuredIn: [String]?
}

/// Decodes an array, dropping the entries that fail.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    private struct Slot<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var out: [Element] = []
        while !container.isAtEnd {
            if let value = try container.decode(Slot<Element>.self).value { out.append(value) }
        }
        elements = out
    }
}

struct ManifestAsset: Codable, Hashable {
    var path: String
    var sha256: String
    var bytes: Int
    var kind: String
    var prefetch: Bool?

    /// The file extension of the stored asset (`m4a`, `json`, `png`).
    var fileExtension: String { (path as NSString).pathExtension }
}

enum ManifestSongStatus: String, Codable, Hashable {
    case live, hidden, comingSoon
}

struct ManifestSong: Decodable, Hashable, Identifiable {
    var id: String
    /// `canonical` is the Indonesian title used as the trophy key; the other languages are for display.
    var title: LocalizedText
    var order: Int
    var packId: String
    var isSolemn: Bool
    var status: ManifestSongStatus
    var minAppBuild: Int
    var chart: String?
    var backing: String?
    var sheet: String?
    var bundledSheetImage: String?
    var region: String?
    var tags: [String]
    var markets: Markets?

    var canonicalTitle: String { title.values["canonical"] ?? title.resolved(preferred: ["id"]) }

    private enum CodingKeys: String, CodingKey {
        case id, title, order, packId, isSolemn, status, minAppBuild, chart, backing, sheet, bundledSheetImage, region, tags, markets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(LocalizedText.self, forKey: .title)
        order = try c.decode(Int.self, forKey: .order)
        packId = try c.decode(String.self, forKey: .packId)
        isSolemn = try c.decodeIfPresent(Bool.self, forKey: .isSolemn) ?? false
        // An unknown status throws, so the song is skipped by `LossyArray`.
        status = try c.decodeIfPresent(ManifestSongStatus.self, forKey: .status) ?? .live
        minAppBuild = try c.decodeIfPresent(Int.self, forKey: .minAppBuild) ?? 0
        chart = try c.decodeIfPresent(String.self, forKey: .chart)
        backing = try c.decodeIfPresent(String.self, forKey: .backing)
        sheet = try c.decodeIfPresent(String.self, forKey: .sheet)
        bundledSheetImage = try c.decodeIfPresent(String.self, forKey: .bundledSheetImage)
        region = try c.decodeIfPresent(String.self, forKey: .region)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        markets = try c.decodeIfPresent(Markets.self, forKey: .markets)
    }
}

struct ManifestPack: Decodable, Hashable, Identifiable {
    struct Access: Decodable, Hashable {
        var type: String
        var productIds: [String]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            productIds = try c.decodeIfPresent([String].self, forKey: .productIds) ?? []
        }

        private enum CodingKeys: String, CodingKey { case type, productIds }
    }

    var id: String
    var title: LocalizedText
    var description: LocalizedText?
    var art: String?
    var access: Access
    var markets: Markets?
}

struct ContentManifest: Decodable {
    var schemaVersion: Int
    var contentVersion: Int
    var createdAt: String
    var minAppBuildIos: Int
    var assets: [String: ManifestAsset]
    var songs: [ManifestSong]
    var packs: [ManifestPack]
    var shopItems: [ShopItem]
    var products: [StoreProduct]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, contentVersion, createdAt, minAppBuild, assets, songs, packs, shop, products
    }

    private struct ShopPart: Decodable { let items: LossyArray<ShopItem> }
    private struct MinBuild: Decodable { let ios: Int? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        contentVersion = try c.decode(Int.self, forKey: .contentVersion)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        minAppBuildIos = try c.decodeIfPresent(MinBuild.self, forKey: .minAppBuild)?.ios ?? 0
        assets = try c.decodeIfPresent([String: ManifestAsset].self, forKey: .assets) ?? [:]
        songs = try c.decodeIfPresent(LossyArray<ManifestSong>.self, forKey: .songs)?.elements ?? []
        packs = try c.decodeIfPresent(LossyArray<ManifestPack>.self, forKey: .packs)?.elements ?? []
        shopItems = try c.decodeIfPresent(ShopPart.self, forKey: .shop)?.items.elements ?? []
        products = try c.decodeIfPresent(LossyArray<StoreProduct>.self, forKey: .products)?.elements ?? []
    }

    static func decode(_ data: Data) throws -> ContentManifest {
        try JSONDecoder().decode(ContentManifest.self, from: data)
    }
}
