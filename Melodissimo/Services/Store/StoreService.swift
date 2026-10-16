//
//  StoreService.swift
//  Melodissimo
//
//  The only place that imports StoreKit. Loads the products, buys them, and listens for transactions from launch.
//  Consumables go through `PurchaseGrants` (verify, grant once, then finish). Task B7.2 extends this same service
//  for Melodissimo Plus and song packs.
//

import Foundation
import StoreKit
import UIKit

/// How a purchase ended, for the UI.
enum PurchaseOutcome: Hashable {
    case success
    /// Waiting for approval (Ask to Buy on a family account); it is granted when the approval arrives.
    case pending
    case cancelled
    case failed
}

@MainActor
final class StoreService: ObservableObject {

    static let shared = StoreService()

    /// Store products by id, for the ids in `ProductCatalog` that the store knows.
    @Published private(set) var storeProducts: [String: Product] = [:]
    @Published private(set) var isLoading = false

    private let progress: ProgressStore
    private let entitlements: Entitlements
    private var updatesTask: Task<Void, Never>?

    init(progress: ProgressStore = .shared, entitlements: Entitlements = .shared) {
        self.progress = progress
        self.entitlements = entitlements
    }

    /// Whether the store is used at all: not in unit tests' offline runs, and not when the backend switch is off.
    /// Call once at launch.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            // Purchases that finished while the app was closed, or that were never finished, arrive first.
            for await result in Transaction.unfinished {
                await self?.handle(result)
            }
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
        // The App Store country decides which packs and prices are offered. Kept for the `X-Storefront` header.
        Task { [weak self] in
            await self?.refreshStorefront()
            for await storefront in Storefront.updates {
                Market.storefront = storefront.countryCode
                self?.objectWillChange.send()
            }
        }
    }

    private func refreshStorefront() async {
        if let storefront = await Storefront.current { Market.storefront = storefront.countryCode }
    }

    /// Loads the products named in the catalog.
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        let ids = ProductCatalog.products.map(\.id)
        guard let loaded = try? await Product.products(for: ids) else { return }
        storeProducts = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
    }

    /// What a paywall shows for one product: its store price, the raw price for comparisons and any free-trial offer.
    struct Offer: Equatable {
        var productId: String
        var displayPrice: String
        var price: Decimal
        /// "7 days free", when the player is still eligible for the introductory offer.
        var trialText: String?
    }

    func offer(for productId: String) async -> Offer? {
        guard let product = storeProducts[productId] else { return nil }
        var trial: String?
        if let subscription = product.subscription, let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial,
           await subscription.isEligibleForIntroOffer {
            let unit: Calendar.Component
            switch intro.period.unit {
            case .day: unit = .day
            case .week: unit = .weekOfYear
            case .month: unit = .month
            default: unit = .year
            }
            trial = PlusPricing.trialText(value: intro.period.value, unit: unit)
        }
        return Offer(productId: productId, displayPrice: product.displayPrice, price: product.price, trialText: trial)
    }

    /// The localized price for a product, from the store only.
    func displayPrice(for productId: String) -> String? {
        storeProducts[productId]?.displayPrice
    }

    func buy(_ productId: String) async -> PurchaseOutcome {
        guard let product = storeProducts[productId] else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard await handle(result) else { return .failed }
                Analytics.log(.purchaseSuccess, props: ["productId": .string(productId)])
                return .success
            case .pending:
                Analytics.log(.purchasePending, props: ["productId": .string(productId)])
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// Asks the store to sync purchases (the "Restore" button), then re-reads what the player owns.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Opens the system sheet to manage or cancel the Plus subscription.
    func manageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    /// Verifies one transaction and settles it: a consumable is granted once, then finished; a pack or subscription updates
    /// what the player owns, then is finished. Returns whether the purchase is now settled.
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else { return false }
        // An id this build doesn't know may belong to a newer catalog: leave it unfinished so that build can grant it.
        guard let product = ProductCatalog.product(id: transaction.productID) else { return false }
        if product.isConsumable {
            // A refunded consumable is not granted.
            guard transaction.revocationDate == nil else {
                await transaction.finish()
                return true
            }
            if PurchaseGrants.apply(transactionId: String(transaction.id), product: product, to: progress) {
                Analytics.log(.coinsPurchased, props: ["productId": .string(product.id), "coins": .number(Double(product.grants?.coins ?? 0))])
            }
        } else {
            await refreshEntitlements()
        }
        await transaction.finish()
        return true
    }

    // MARK: Entitlements

    /// Reads `Transaction.currentEntitlements` (verified, not revoked; a subscription appears only while valid) and the
    /// Plus subscription's status, and gives them to `Entitlements`.
    func refreshEntitlements() async {
        var owned: [OwnedProduct] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            owned.append(OwnedProduct(productId: transaction.productID, expiresAt: transaction.expirationDate))
        }
        entitlements.apply(products: owned, plus: await plusStatus(owned: owned))
    }

    private func plusStatus(owned: [OwnedProduct]) async -> PlusStatus {
        let plusProducts = ProductCatalog.products.filter { Entitlements.isPlusProduct($0.id) }.map(\.id)
        guard !plusProducts.isEmpty else { return .none }
        if storeProducts.isEmpty { await loadProducts() }
        guard let subscription = plusProducts.compactMap({ storeProducts[$0]?.subscription }).first,
              let statuses = try? await subscription.status,
              let status = statuses.first(where: { s in
                  guard case .verified(let t) = s.transaction else { return false }
                  return plusProducts.contains(t.productID)
              }) else {
            return owned.contains { Entitlements.isPlusProduct($0.productId) } ? .active(renews: nil) : .none
        }
        switch status.state {
        case .subscribed:
            var renews: Date?
            if case .verified(let info) = status.renewalInfo { renews = info.renewalDate }
            if renews == nil, case .verified(let t) = status.transaction { renews = t.expirationDate }
            return .active(renews: renews)
        case .inGracePeriod, .inBillingRetryPeriod:
            return .gracePeriod
        case .expired:
            return .expired
        case .revoked:
            return .none
        default:
            return .none
        }
    }
}
