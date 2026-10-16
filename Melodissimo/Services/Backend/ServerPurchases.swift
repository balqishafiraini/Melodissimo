//
//  ServerPurchases.swift
//  Melodissimo
//
//  The app reports each verified App Store transaction to the backend (Task B8.3), and reads back everything the signed-in player
//  owns, so Plus and packs follow them across devices (and to Android later). StoreKit stays the authority on this device;
//  the server adds to it.
//

import Foundation

struct ServerPurchases {

    private struct Reported: Decodable { let ok: Bool? }
    private struct ReportBody: Encodable { let signedTransaction: String }

    struct Mine: Decodable {
        struct Entitlement: Decodable {
            let productId: String
            let expiresAt: Date?
        }
        struct Ledger: Decodable {
            let coins: Int
            let items: [String: Int]
        }
        let entitlements: [Entitlement]
        let ledger: Ledger
    }

    var makeClient: () -> APIClient = { APIClient(authorization: { KeychainStore().read("playerToken") }) }
    var isEnabled: () -> Bool = { BackendEnvironment.isEnabled && FeatureFlags.isOn(.accounts) && KeychainStore().read("playerToken") != nil }

    /// Sends a StoreKit 2 signed transaction (`VerificationResult.jwsRepresentation`). Safe to repeat: the server grants each
    /// consumable transaction once and updates an entitlement in place.
    @discardableResult
    func report(signedTransaction: String) async -> Bool {
        guard isEnabled() else { return false }
        return (try? await makeClient().post("v1/purchases/apple", body: ReportBody(signedTransaction: signedTransaction)) as Reported) != nil
    }

    /// Reads the player's entitlements and ledger and applies them: entitlements join the StoreKit ones, and the ledger's coins
    /// and items are restored with `max`.
    @discardableResult
    func refresh(entitlements: Entitlements = .shared, progress: ProgressStore = .shared) async -> Bool {
        guard isEnabled(), let mine: Mine = try? await makeClient().get("v1/players/me/entitlements") else { return false }
        entitlements.applyServer(products: mine.entitlements.map { OwnedProduct(productId: $0.productId, expiresAt: $0.expiresAt) })
        progress.restorePurchased(coins: mine.ledger.coins, items: mine.ledger.items)
        return true
    }
}
