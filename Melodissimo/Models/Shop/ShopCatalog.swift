//
//  ShopCatalog.swift
//  Melodissimo
//

import Foundation

/// Where the shop's stock comes from. The app ships `Data/Shop/shop.json`; downloaded content can replace it.
protocol ShopCatalogSource {
    var items: [ShopItem] { get }
}

/// The catalog bundled with the app (`shop.json`, the manifest's `shop` shape). Decoded once per launch.
struct BundledShopSource: ShopCatalogSource {
    private static let decoded: [ShopItem] = {
        guard let url = Bundle.main.url(forResource: "shop", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return ShopCatalog.decode(data)
    }()

    var items: [ShopItem] { Self.decoded }
}

/// The shop's stock. `items` is everything known, so an owned or equipped item can always be found even after
/// it stops being sold; `visibleItems` is what the shop shows.
enum ShopCatalog {

    /// The active source. Tests swap it.
    static var source: ShopCatalogSource = BundledShopSource()

    /// Every item the source holds, ordered by `order` (ties keep file order).
    static var items: [ShopItem] {
        source.items.enumerated()
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
            .map(\.element)
    }

    /// Decodes `{ "items": [...] }`. An item with an unknown category, kind or status, or a broken field, is skipped
    /// and never takes the rest down with it.
    static func decode(_ data: Data) -> [ShopItem] {
        struct Lossy: Decodable {
            let item: ShopItem?
            init(from decoder: Decoder) throws { item = try? ShopItem(from: decoder) }
        }
        struct File: Decodable { let items: [Lossy] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(File.self, from: data) else { return [] }
        return file.items.compactMap(\.item)
    }

    static func items(in category: ShopCategory) -> [ShopItem] {
        items.filter { $0.category == category }
    }

    static func item(id: String) -> ShopItem? {
        items.first { $0.id == id }
    }

    /// The free item an equippable category starts with.
    static func defaultItem(for category: ShopCategory) -> ShopItem {
        items(in: category).first { $0.isDefault } ?? ShopItem.fallbackDefault(for: category)
    }

    /// The app's build number (`CFBundleVersion`), or a value that passes every `minAppBuild` when unreadable.
    static var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? Int.max
    }

    /// Whether the shop may offer the item: live, built for this app, and inside its availability window.
    static func isOnSale(_ item: ShopItem, now: Date = Date(), build: Int = currentBuild) -> Bool {
        guard item.status == .live, item.minAppBuild <= build else { return false }
        if let from = item.availableFrom, now < from { return false }
        if let until = item.availableUntil, now >= until { return false }
        return true
    }

    /// What a category's shop page shows: items on sale, plus every item the player already owns, which never
    /// disappears (free defaults count as owned).
    static func visibleItems(in category: ShopCategory, owned: Set<String>,
                             now: Date = Date(), build: Int = currentBuild) -> [ShopItem] {
        items(in: category).filter { item in
            item.isDefault || owned.contains(item.id) || isOnSale(item, now: now, build: build)
        }
    }

    /// Categories that have something to show.
    static func visibleCategories(owned: Set<String>, now: Date = Date(), build: Int = currentBuild) -> [ShopCategory] {
        ShopCategory.allCases.filter { !visibleItems(in: $0, owned: owned, now: now, build: build).isEmpty }
    }
}
