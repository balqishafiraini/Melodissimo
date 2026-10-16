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
    private var updatesTask: Task<Void, Never>?

    init(progress: ProgressStore = .shared) {
        self.progress = progress
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
    }

    /// Loads the products named in the catalog.
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        let ids = ProductCatalog.products.map(\.id)
        guard let loaded = try? await Product.products(for: ids) else { return }
        storeProducts = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
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
                return .success
            case .pending:
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

    /// Verifies one transaction, grants it once and finishes it. Returns whether the purchase is now settled.
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else { return false }
        // An id this build doesn't know may belong to a newer catalog: leave it unfinished so that build can grant it.
        guard let product = ProductCatalog.product(id: transaction.productID), product.isConsumable else { return false }
        PurchaseGrants.apply(transactionId: String(transaction.id), product: product, to: progress)
        await transaction.finish()
        return true
    }
}
