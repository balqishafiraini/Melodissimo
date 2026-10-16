//
//  ShopItem.swift
//  Melodissimo
//

import Foundation

/// What a shop item changes. The raw value is also the suffix of the `equip_<category>` key.
/// A category the app doesn't know decodes to an error, so the item is skipped.
enum ShopCategory: String, CaseIterable, Hashable {
    case keyboard
    case notes
    case outfit
    /// Consumables such as hearts. They are used up, never worn.
    case boost

    /// Categories whose items can be worn (they have a free default and an `equip_` key).
    static var equippable: [ShopCategory] { allCases.filter { $0 != .boost } }
}

/// `cosmetic` items are owned once and can be worn; `consumable` ones are a stack the player uses up.
enum ShopItemKind: String, Hashable {
    case cosmetic
    case consumable
}

/// Whether an item is on sale. `hidden` and `comingSoon` items are not shown; owned ones still work.
enum ShopItemStatus: String, Hashable {
    case live
    case hidden
    case comingSoon
}

/// Image names for an item's art that are already in the asset catalog.
struct ShopArtNames: Codable, Hashable {
    var preview: String?
    var overlay: String?
}

/// One thing the player can buy with coins, in the shape of the manifest's `shop.items` (`BACKEND_PLAN.md`
/// §4.3). Every equippable category has one free default that is always owned.
struct ShopItem: Identifiable, Hashable {
    /// `<category>_<variant>`, e.g. `keyboard_batik`. Stored in `shop_owned` and `equip_*`, so never rename.
    let id: String
    let category: ShopCategory
    var kind: ShopItemKind = .cosmetic
    /// Shown by `name`. Most are Indonesian names that read the same in both languages.
    let names: LocalizedText
    /// Price in coins. Real money never appears here.
    let price: Int
    /// Keyboard skins: `[body, pressed key]` as 0xRRGGBB. Empty keeps the app's normal look.
    var colors: [UInt32] = []
    var order: Int = 0
    var tags: [String] = []
    var availableFrom: Date? = nil
    var availableUntil: Date? = nil
    var plusOnly: Bool = false
    /// Consumables: the most a player can hold.
    var maxStack: Int? = nil
    var bundledArt: ShopArtNames? = nil
    /// Names of downloaded assets (used once remote content lands).
    var art: ShopArtNames? = nil
    var minAppBuild: Int = 0
    var status: ShopItemStatus = .live
    /// Where the item is offered; `nil` means worldwide (`BACKEND_PLAN.md` §4.10).
    var markets: Markets? = nil

    var isDefault: Bool { price == 0 && kind == .cosmetic }

    /// The name in the player's language.
    var name: String { names.resolved() }

    /// The part of the id after the category: `batik`, `rainbow`, `royal`, ...
    var variant: String {
        guard let underscore = id.firstIndex(of: "_") else { return id }
        return String(id[id.index(after: underscore)...])
    }

    init(id: String, category: ShopCategory, name: String, price: Int, colors: [UInt32] = []) {
        self.init(id: id, category: category, names: LocalizedText(name), price: price, colors: colors)
    }

    init(id: String, category: ShopCategory, names: LocalizedText, price: Int, colors: [UInt32] = []) {
        self.id = id
        self.category = category
        self.names = names
        self.price = price
        self.colors = colors
    }

    /// The free item a category falls back to when the catalog can't be read.
    static func fallbackDefault(for category: ShopCategory) -> ShopItem {
        let id: String
        switch category {
        case .keyboard: id = "keyboard_navy"
        case .notes: id = "notes_default"
        case .outfit: id = "outfit_none"
        case .boost: id = "boost_none"
        }
        return ShopItem(id: id, category: category, name: "Default", price: 0)
    }
}

extension ShopItem: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, category, kind, name, price, colors, order, tags, availableFrom, availableUntil
        case plusOnly, maxStack, bundledArt, art, minAppBuild, status, markets
    }

    private struct Price: Decodable { let coins: Int }

    /// Fails for an unknown `category`, `kind` or `status`, so the catalog can skip the item.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func raw<T: RawRepresentable>(_ key: CodingKeys, _ type: T.Type, default fallback: T? = nil) throws -> T
        where T.RawValue == String {
            guard let text = try c.decodeIfPresent(String.self, forKey: key) else {
                if let fallback { return fallback }
                throw DecodingError.keyNotFound(key, .init(codingPath: c.codingPath, debugDescription: "missing"))
            }
            guard let value = T(rawValue: text) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "unknown value \(text)")
            }
            return value
        }
        id = try c.decode(String.self, forKey: .id)
        category = try raw(.category, ShopCategory.self)
        kind = try raw(.kind, ShopItemKind.self, default: .cosmetic)
        names = try c.decode(LocalizedText.self, forKey: .name)
        price = try c.decode(Price.self, forKey: .price).coins
        colors = try (c.decodeIfPresent([String].self, forKey: .colors) ?? []).map { hex in
            guard hex.hasPrefix("#"), let value = UInt32(hex.dropFirst(), radix: 16) else {
                throw DecodingError.dataCorruptedError(forKey: .colors, in: c, debugDescription: "bad color \(hex)")
            }
            return value
        }
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        availableFrom = try c.decodeIfPresent(Date.self, forKey: .availableFrom)
        availableUntil = try c.decodeIfPresent(Date.self, forKey: .availableUntil)
        plusOnly = try c.decodeIfPresent(Bool.self, forKey: .plusOnly) ?? false
        maxStack = try c.decodeIfPresent(Int.self, forKey: .maxStack)
        bundledArt = try c.decodeIfPresent(ShopArtNames.self, forKey: .bundledArt)
        art = try c.decodeIfPresent(ShopArtNames.self, forKey: .art)
        minAppBuild = try c.decodeIfPresent(Int.self, forKey: .minAppBuild) ?? 0
        status = try raw(.status, ShopItemStatus.self, default: .live)
        markets = try c.decodeIfPresent(Markets.self, forKey: .markets)
    }
}
