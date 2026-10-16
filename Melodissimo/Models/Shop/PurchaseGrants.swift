//
//  PurchaseGrants.swift
//  Melodissimo
//
//  Paid consumables are granted exactly once per store transaction (`BACKEND_PLAN.md` §5.4). The ledger `iap_granted`
//  holds one entry per transaction, `<productId>:<transactionId>`, and merges across devices as a union.
//

import Foundation

/// Reads the ledger of transactions already granted.
struct PurchaseLedger {
    let entries: [String]

    func hasGranted(transactionId: String) -> Bool {
        entries.contains { $0.hasSuffix(":" + transactionId) }
    }

    func hasGranted(productId: String) -> Bool {
        entries.contains { $0.hasPrefix(productId + ":") }
    }
}

enum PurchaseGrants {

    static let ledgerKey = "iap_granted"

    static func ledger(in store: ProgressStore) -> PurchaseLedger {
        PurchaseLedger(entries: store.defaults.stringArray(forKey: ledgerKey) ?? [])
    }

    /// Grants a verified consumable purchase: the coins and items, then the ledger entry, back to back. Returns `true`
    /// the first time a transaction id is seen and `false` for a repeat delivery (nothing is granted again) or a
    /// product that grants nothing.
    ///
    /// The caller finishes the store transaction afterwards. If the app dies before that, the store delivers it again
    /// and the ledger stops a second grant.
    @discardableResult
    static func apply(transactionId: String, product: StoreProduct, to store: ProgressStore) -> Bool {
        guard product.isConsumable, let grants = product.grants else { return false }
        guard !ledger(in: store).hasGranted(transactionId: transactionId) else { return false }
        store.addPurchasedCoins(grants.coins)
        for (itemId, count) in grants.items.sorted(by: { $0.key < $1.key }) {
            // Paid items are never cut off by a stack limit; an item the catalog no longer lists stays in the inventory.
            store.addToInventory(itemId, count: count, maxStack: .max)
        }
        var entries = store.defaults.stringArray(forKey: ledgerKey) ?? []
        entries.append("\(product.id):\(transactionId)")
        store.defaults.set(entries, forKey: ledgerKey)
        store.objectWillChange.send()
        return true
    }
}
