//
//  ProgressStore+Inventory.swift
//  Melodissimo
//
//  Consumables the player holds, such as hearts. Each item keeps two totals that only ever increase,
//  `inv_gained_<itemId>` and `inv_used_<itemId>`, so two devices merge them with `max` and agree on
//  `count = gained − used`. Neither total is touched by "Reset progress": hearts may have been paid for.
//

import Foundation

extension ProgressStore {

    /// The most of one consumable a player can hold when the item doesn't say otherwise.
    static let defaultMaxStack = 99

    private func gainedKey(_ itemId: String) -> String { "inv_gained_\(itemId)" }
    private func usedKey(_ itemId: String) -> String { "inv_used_\(itemId)" }

    /// How many of an item the player holds: gained − used, from 0 up to `maxStack`.
    func inventoryCount(_ itemId: String, maxStack: Int = ProgressStore.defaultMaxStack) -> Int {
        let held = defaults.integer(forKey: gainedKey(itemId)) - defaults.integer(forKey: usedKey(itemId))
        return min(max(held, 0), max(maxStack, 0))
    }

    /// Adds `count` of an item (a purchase, a grant, a reward). Returns how many were actually added: fewer
    /// than asked when the stack is full, and 0 when it already is.
    @discardableResult
    func addToInventory(_ itemId: String, count: Int = 1, maxStack: Int = ProgressStore.defaultMaxStack) -> Int {
        let room = max(maxStack, 0) - inventoryCount(itemId, maxStack: maxStack)
        let added = min(max(count, 0), room)
        guard added > 0 else { return 0 }
        defaults.set(defaults.integer(forKey: gainedKey(itemId)) + added, forKey: gainedKey(itemId))
        objectWillChange.send()
        return added
    }

    /// Uses one of an item. Returns `false`, changing nothing, when the player has none.
    @discardableResult
    func useFromInventory(_ itemId: String) -> Bool {
        guard inventoryCount(itemId, maxStack: .max) > 0 else { return false }
        defaults.set(defaults.integer(forKey: usedKey(itemId)) + 1, forKey: usedKey(itemId))
        objectWillChange.send()
        return true
    }

    /// Buys `count` of a consumable with coins. All or nothing: `false`, changing nothing, when the stack
    /// can't hold that many or the balance is short.
    @discardableResult
    func buyConsumable(_ item: ShopItem, count: Int = 1, maxStack: Int = ProgressStore.defaultMaxStack) -> Bool {
        guard count > 0, inventoryCount(item.id, maxStack: maxStack) + count <= maxStack,
              spend(item.price * count) else { return false }
        addToInventory(item.id, count: count, maxStack: maxStack)
        return true
    }

    /// Brings back what the server's ledger says was bought with real money (after a reinstall or on another device): each
    /// total only ever goes up, so this never takes anything away.
    func restorePurchased(coins: Int, items: [String: Int]) {
        if coins > coinsPurchasedTotal { defaults.set(coins, forKey: "coins_purchasedTotal") }
        for (id, count) in items where count > defaults.integer(forKey: gainedKey(id)) { defaults.set(count, forKey: gainedKey(id)) }
        objectWillChange.send()
    }
}
