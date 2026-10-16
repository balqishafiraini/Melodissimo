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

/// The shop's stock from the content store (a downloaded release, else the bundled baseline), falling back to the
/// bundled `shop.json` when the store has none.
struct ContentStoreShopSource: ShopCatalogSource {
    var store: ContentStore = .shared

    var items: [ShopItem] {
        let bundled = BundledShopSource().items
        let remote = store.shopItems
        guard !remote.isEmpty else { return bundled }
        // An item that shipped with the app never disappears, even if a release stops listing it: a player who bought
        // it keeps it, owned and equipped.
        let listed = Set(remote.map(\.id))
        return remote + bundled.filter { !listed.contains($0.id) }
    }
}

/// The shop's stock. `items` is everything known, so an owned or equipped item can always be found even after
/// it stops being sold; `visibleItems` is what the shop shows.
enum ShopCatalog {

    /// The active source. Tests swap it.
    static var source: ShopCatalogSource = ContentStoreShopSource()

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
                             now: Date = Date(), build: Int = currentBuild,
                             artIsAvailable: (ShopItem) -> Bool = { hasArt($0) },
                             storefront: String? = Market.storefront, deviceCountry: String? = Market.deviceCountry,
                             plusAvailable: Bool = FeatureFlags.isOn(.packStore)) -> [ShopItem] {
        let shown = items(in: category).filter { item in
            guard artIsAvailable(item) else { return false }
            if item.isDefault || owned.contains(item.id) { return true }
            // Plus-only items appear once Plus can be offered (the pack store is on); they are never shown "broken".
            if item.plusOnly && !plusAvailable { return false }
            return isOnSale(item, now: now, build: build)
                && Markets.allows(item.markets, storefront: storefront, deviceCountry: deviceCountry)
        }
        return Markets.featuredFirst(shown, markets: \.markets, storefront: storefront, deviceCountry: deviceCountry)
    }

    /// Whether the player can buy an item now: a Plus-only item needs an active Plus subscription. Owning it is forever.
    static func canBuy(_ item: ShopItem, isPlus: Bool) -> Bool {
        !item.plusOnly || isPlus
    }

    /// Whether an item can be drawn: it has art in the app (`bundledArt`), no downloaded art to wait for, or all of its
    /// downloaded art is on disk. An item whose art hasn't arrived yet is hidden rather than shown broken.
    static func hasArt(_ item: ShopItem, store: ContentStore = .shared) -> Bool {
        if item.bundledArt?.preview != nil { return true }
        guard let art = item.art else { return true }
        return [art.preview, art.overlay].compactMap { $0 }.allSatisfy { store.url(forAsset: $0) != nil }
    }

    /// The downloadable art keys of items that are on sale or owned, to fetch when the shop opens or a release is staged.
    static func artKeys(of items: [ShopItem]) -> [String] {
        items.flatMap { [$0.art?.preview, $0.art?.overlay] }.compactMap { $0 }
    }

    /// Categories that have something to show.
    static func visibleCategories(owned: Set<String>, now: Date = Date(), build: Int = currentBuild,
                                  artIsAvailable: (ShopItem) -> Bool = { hasArt($0) },
                                  storefront: String? = Market.storefront, deviceCountry: String? = Market.deviceCountry,
                                  plusAvailable: Bool = FeatureFlags.isOn(.packStore)) -> [ShopCategory] {
        ShopCategory.allCases.filter {
            !visibleItems(in: $0, owned: owned, now: now, build: build, artIsAvailable: artIsAvailable,
                          storefront: storefront, deviceCountry: deviceCountry, plusAvailable: plusAvailable).isEmpty
        }
    }
}
