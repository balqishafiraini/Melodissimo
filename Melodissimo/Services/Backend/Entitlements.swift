//
//  Entitlements.swift
//  Melodissimo
//
//  What the player owns: store products with their expiry, and the Melodissimo Plus status. `StoreService` (the only StoreKit
//  code) fills it from `Transaction.currentEntitlements`; the last answer is cached in `UserDefaults` so an offline launch
//  still unlocks what was bought, until a subscription's known end date passes.
//

import Foundation

enum PlusStatus: Equatable, Codable {
    case none
    /// An active subscription, renewing on this date when the store knows it.
    case active(renews: Date?)
    /// Payment trouble, but the store still grants access for now.
    case gracePeriod
    case expired

    /// Whether Plus content is open.
    var isActive: Bool {
        switch self {
        case .active, .gracePeriod: return true
        case .none, .expired: return false
        }
    }
}

/// One thing the player owns, as StoreKit reported it.
struct OwnedProduct: Codable, Equatable {
    var productId: String
    /// When it stops being valid (subscriptions); `nil` for a purchase that never expires.
    var expiresAt: Date?
}

final class Entitlements: ObservableObject {

    static let shared = Entitlements()

    private static let cacheKey = "entitlements_cache"

    private struct Cache: Codable {
        var products: [OwnedProduct]
        var plus: PlusStatus
        /// What the backend says the player owns (bought on another device or platform).
        var server: [OwnedProduct]?
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private var products: [OwnedProduct]
    private var storedPlus: PlusStatus
    private var serverProducts: [OwnedProduct] = []

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.cacheKey), let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            products = cache.products
            storedPlus = cache.plus
            serverProducts = cache.server ?? []
        } else {
            products = []
            storedPlus = .none
        }
    }

    /// The products that are valid right now: a subscription past its end date no longer counts, even if the store hasn't
    /// answered yet (an offline launch after the plan lapsed).
    var ownedProductIds: Set<String> {
        let current = now()
        return Set((products + serverProducts).filter { $0.expiresAt.map { $0 > current } ?? true }.map(\.productId))
    }

    /// The Plus status, corrected for an end date that has passed.
    var plusStatus: PlusStatus {
        let local: PlusStatus
        switch storedPlus {
        case .active(let renews):
            local = (renews.map { $0 < now() } ?? false) && !ownedProductIds.contains(where: Self.isPlusProduct) ? .expired : storedPlus
        default:
            local = storedPlus
        }
        if local.isActive { return local }
        // Plus bought on another device or platform counts here too.
        let current = now()
        if let remote = serverProducts.filter({ Self.isPlusProduct($0.productId) && ($0.expiresAt.map { $0 > current } ?? true) }).max(by: { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }) {
            return .active(renews: remote.expiresAt)
        }
        return local
    }

    var isPlusActive: Bool { plusStatus.isActive }

    /// The product ids of the Plus subscription (monthly and yearly): ids under `melodissimo.plus.`.
    static func isPlusProduct(_ id: String) -> Bool { id.hasPrefix("melodissimo.plus.") }

    /// Replaces what is owned with StoreKit's latest answer and caches it.
    func apply(products: [OwnedProduct], plus: PlusStatus) {
        let change = { [self] in
            self.products = products
            storedPlus = plus
            objectWillChange.send()
        }
        if Thread.isMainThread { change() } else { DispatchQueue.main.async(execute: change) }
        persist(products: products, plus: plus, server: serverProducts)
    }

    /// Adds what the backend knows the player owns (union with what StoreKit says) and caches it.
    func applyServer(products server: [OwnedProduct]) {
        let change = { [self] in
            serverProducts = server
            objectWillChange.send()
        }
        if Thread.isMainThread { change() } else { DispatchQueue.main.async(execute: change) }
        persist(products: products, plus: storedPlus, server: server)
    }

    private func persist(products: [OwnedProduct], plus: PlusStatus, server: [OwnedProduct]) {
        if let data = try? JSONEncoder().encode(Cache(products: products, plus: plus, server: server)) {
            defaults.set(data, forKey: Self.cacheKey)
        }
    }

    /// Whether a pack is open to this player.
    func isUnlocked(_ pack: ManifestPack) -> Bool {
        ContentAccess.isUnlocked(pack: pack, owned: ownedProductIds)
    }

    func isUnlocked(packId: String, packs: [ManifestPack]) -> Bool {
        ContentAccess.isUnlocked(packId: packId, packs: packs, owned: ownedProductIds)
    }
}
