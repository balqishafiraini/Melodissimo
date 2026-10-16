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
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private var products: [OwnedProduct]
    private var storedPlus: PlusStatus

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.cacheKey), let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            products = cache.products
            storedPlus = cache.plus
        } else {
            products = []
            storedPlus = .none
        }
    }

    /// The products that are valid right now: a subscription past its end date no longer counts, even if the store hasn't
    /// answered yet (an offline launch after the plan lapsed).
    var ownedProductIds: Set<String> {
        let current = now()
        return Set(products.filter { $0.expiresAt.map { $0 > current } ?? true }.map(\.productId))
    }

    /// The Plus status, corrected for an end date that has passed.
    var plusStatus: PlusStatus {
        switch storedPlus {
        case .active(let renews):
            if let renews, renews < now(), !ownedProductIds.contains(where: Self.isPlusProduct) { return .expired }
            return storedPlus
        default:
            return storedPlus
        }
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
        if let data = try? JSONEncoder().encode(Cache(products: products, plus: plus)) {
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
