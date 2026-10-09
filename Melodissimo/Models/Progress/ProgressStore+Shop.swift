//
//  ProgressStore+Shop.swift
//  Melodissimo
//
//  What the player owns and wears: `shop_owned` (item ids) and `equip_keyboard`, `equip_notes`,
//  `equip_outfit`. Defaults are free and always owned, so they are never written to `shop_owned`.
//

import Foundation

extension ProgressStore {

    private var ownedKey: String { "shop_owned" }

    private func equipKey(_ category: ShopCategory) -> String {
        "equip_\(category.rawValue)"
    }

    /// Ids of the items bought so far.
    var purchasedShopItemIds: Set<String> {
        Set(defaults.stringArray(forKey: ownedKey) ?? [])
    }

    /// How many items have been bought (feeds the Kolektor achievement).
    var purchasedShopItemCount: Int {
        let known = Set(ShopCatalog.items.map(\.id))
        return purchasedShopItemIds.intersection(known).count
    }

    func owns(_ item: ShopItem) -> Bool {
        item.isDefault || purchasedShopItemIds.contains(item.id)
    }

    /// Pays for an item and adds it to what the player owns. Returns `false`, changing nothing, when the
    /// item is already owned or the balance is short.
    @discardableResult
    func buy(_ item: ShopItem) -> Bool {
        guard !owns(item), spend(item.price) else { return false }
        var ids = defaults.stringArray(forKey: ownedKey) ?? []
        ids.append(item.id)
        defaults.set(ids, forKey: ownedKey)
        objectWillChange.send()
        return true
    }

    /// The item worn in a category: the one equipped, or the category's default.
    func equippedItem(_ category: ShopCategory) -> ShopItem {
        if let id = defaults.string(forKey: equipKey(category)),
           let item = ShopCatalog.item(id: id), item.category == category, owns(item) {
            return item
        }
        return ShopCatalog.defaultItem(for: category)
    }

    /// Wears an item the player owns. Returns `false` when it isn't theirs yet.
    @discardableResult
    func equip(_ item: ShopItem) -> Bool {
        guard owns(item) else { return false }
        defaults.set(item.id, forKey: equipKey(item.category))
        objectWillChange.send()
        return true
    }
}
