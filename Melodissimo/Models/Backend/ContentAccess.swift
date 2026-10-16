//
//  ContentAccess.swift
//  Melodissimo
//

import Foundation

/// Who may open which pack (`BACKEND_PLAN.md` §5.3). Pure: the owned products come from `Entitlements`.
///
/// - `free` packs are open to everyone, forever (the 16 national songs are in `core`).
/// - A `product` pack opens when any of its `productIds` is owned. An owned subscription counts only while it is active
///   (not expired or revoked; a billing grace period counts as active), which `Entitlements` already applies.
/// - When Plus lapses, Plus-only packs lock again. A pack bought on its own stays open forever.
/// Progress, stars and coins earned in a locked song are never deleted.
enum ContentAccess {

    static func isUnlocked(accessType: String, productIds: [String], owned: Set<String>) -> Bool {
        switch accessType {
        case "free": return true
        case "product": return productIds.contains { owned.contains($0) }
        // A type this build doesn't know stays locked: it may mean something we can't check.
        default: return false
        }
    }

    static func isUnlocked(pack: ManifestPack, owned: Set<String>) -> Bool {
        isUnlocked(accessType: pack.access.type, productIds: pack.access.productIds, owned: owned)
    }

    /// Whether a song can be played: its pack is unlocked. A song whose pack the release doesn't list is treated as
    /// part of the free core pack (the legacy songs, and a release that is missing a pack, must not lock anyone out).
    static func isUnlocked(packId: String, packs: [ManifestPack], owned: Set<String>) -> Bool {
        guard let pack = packs.first(where: { $0.id == packId }) else { return packId == "core" || packs.isEmpty }
        return isUnlocked(pack: pack, owned: owned)
    }
}
