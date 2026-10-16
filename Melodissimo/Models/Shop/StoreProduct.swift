//
//  StoreProduct.swift
//  Melodissimo
//

import Foundation

/// What a consumable product hands over once it is bought (`BACKEND_PLAN.md` §4.3 `grants`). Real prices are never here:
/// they come from the store (`Product.displayPrice`).
struct PurchaseGrant: Codable, Hashable {
    var coins: Int = 0
    /// Inventory item id to count, e.g. `boost_heart: 5`.
    var items: [String: Int] = [:]

    init(coins: Int = 0, items: [String: Int] = [:]) {
        self.coins = coins
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        items = try c.decodeIfPresent([String: Int].self, forKey: .items) ?? [:]
    }
}

/// A product in the manifest's `products` shape. The type is a string so a type this build doesn't know decodes fine
/// and is simply not sold.
struct StoreProduct: Codable, Hashable, Identifiable {
    var id: String
    var type: String
    var grants: PurchaseGrant? = nil
    var oncePerPlayer: Bool = false
    var order: Int = 0
    var badge: String? = nil
    var group: String? = nil
    var unlocks: [String] = []
    var markets: Markets? = nil

    var isConsumable: Bool { type == "consumable" }

    init(id: String, type: String, grants: PurchaseGrant? = nil, oncePerPlayer: Bool = false, order: Int = 0,
         badge: String? = nil, group: String? = nil, unlocks: [String] = []) {
        self.id = id
        self.type = type
        self.grants = grants
        self.oncePerPlayer = oncePerPlayer
        self.order = order
        self.badge = badge
        self.group = group
        self.unlocks = unlocks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        grants = try c.decodeIfPresent(PurchaseGrant.self, forKey: .grants)
        oncePerPlayer = try c.decodeIfPresent(Bool.self, forKey: .oncePerPlayer) ?? false
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        badge = try c.decodeIfPresent(String.self, forKey: .badge)
        group = try c.decodeIfPresent(String.self, forKey: .group)
        unlocks = try c.decodeIfPresent([String].self, forKey: .unlocks) ?? []
        markets = try c.decodeIfPresent(Markets.self, forKey: .markets)
    }
}

/// The products the app sells. Bundled as `Data/Shop/products.json`; downloaded content can replace the source.
enum ProductCatalog {

    /// Replaces the list when set (tests). `nil` reads the content store.
    static var override: [StoreProduct]?

    /// The products for sale: the content store's (a release or the baseline), else the bundled `products.json`.
    static var products: [StoreProduct] {
        get {
            if let override { return override }
            let remote = ContentStore.shared.products
            return remote.isEmpty ? bundled() : remote.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
        }
        set { override = newValue }
    }

    /// Decodes `{ "products": [...] }`, skipping any entry that doesn't decode.
    static func decode(_ data: Data) -> [StoreProduct] {
        struct Lossy: Decodable {
            let product: StoreProduct?
            init(from decoder: Decoder) throws { product = try? StoreProduct(from: decoder) }
        }
        struct File: Decodable { let products: [Lossy] }
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.products.compactMap(\.product).sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    static func bundled() -> [StoreProduct] {
        guard let url = Bundle.main.url(forResource: "products", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return decode(data)
    }

    static func product(id: String) -> StoreProduct? {
        products.first { $0.id == id }
    }

    /// The coin packs and bundles for sale, hiding one-per-player products already bought.
    static func consumablesOnSale(granted ledger: PurchaseLedger,
                                  storefront: String? = Market.storefront, deviceCountry: String? = Market.deviceCountry) -> [StoreProduct] {
        products.filter {
            $0.isConsumable && !($0.oncePerPlayer && ledger.hasGranted(productId: $0.id))
                && Markets.allows($0.markets, storefront: storefront, deviceCountry: deviceCountry)
        }
    }
}
