//
//  ShopCatalog.swift
//  Melodissimo
//

import Foundation

/// What a shop item changes. The raw value is also the suffix of the `equip_<category>` key.
enum ShopCategory: String, CaseIterable, Hashable {
    case keyboard
    case notes
    case outfit
}

/// One thing the player can buy with coins. Every category has one free default that is always owned.
struct ShopItem: Identifiable, Hashable {
    /// `<category>_<variant>`, e.g. `keyboard_batik`. Stored in `shop_owned` and `equip_*`, so never rename.
    let id: String
    let category: ShopCategory
    /// Shown as is: most are Indonesian names that read the same in both languages. "Default" is translated.
    let name: String
    let price: Int
    /// Keyboard skins: `[body, pressed key]` as 0xRRGGBB. Empty keeps the app's normal look.
    var colors: [UInt32] = []

    var isDefault: Bool { price == 0 }

    /// The part of the id after the category: `batik`, `rainbow`, `royal`, ...
    var variant: String {
        guard let underscore = id.firstIndex(of: "_") else { return id }
        return String(id[id.index(after: underscore)...])
    }
}

/// The shop's stock, following the game plan (§2.4): about 2,000 coins of cosmetics in all.
enum ShopCatalog {

    static let items: [ShopItem] = [
        // Keyboard skins.
        ShopItem(id: "keyboard_navy", category: .keyboard, name: "Navy", price: 0),
        ShopItem(id: "keyboard_batik", category: .keyboard, name: "Merah Batik", price: 100, colors: [0x7B241C, 0xD35400]),
        ShopItem(id: "keyboard_forest", category: .keyboard, name: "Hijau Hutan", price: 150, colors: [0x145A32, 0x229954]),
        ShopItem(id: "keyboard_sea", category: .keyboard, name: "Biru Laut", price: 150, colors: [0x1A5276, 0x2E86C1]),
        ShopItem(id: "keyboard_gold", category: .keyboard, name: "Emas", price: 300, colors: [0xB7950B, 0xD4AC0D]),
        // Falling-note skins.
        ShopItem(id: "notes_default", category: .notes, name: "Default", price: 0),
        ShopItem(id: "notes_rainbow", category: .notes, name: "Pelangi", price: 200),
        ShopItem(id: "notes_neon", category: .notes, name: "Neon", price: 250),
        // Alpanica's outfits.
        ShopItem(id: "outfit_none", category: .outfit, name: "Default", price: 0),
        ShopItem(id: "outfit_glasses", category: .outfit, name: "Kacamata", price: 150),
        ShopItem(id: "outfit_crown", category: .outfit, name: "Mahkota", price: 300),
        ShopItem(id: "outfit_royal", category: .outfit, name: "Raja Gaya", price: 500)
    ]

    static func items(in category: ShopCategory) -> [ShopItem] {
        items.filter { $0.category == category }
    }

    static func item(id: String) -> ShopItem? {
        items.first { $0.id == id }
    }

    /// The free item a category starts with.
    static func defaultItem(for category: ShopCategory) -> ShopItem {
        items(in: category).first { $0.isDefault } ?? items(in: category)[0]
    }
}
