//
//  PlayerAccount.swift
//  Melodissimo
//
//  Who the player is to the backend (`BACKEND_PLAN.md` Task B8.1). Everything works without an account. When accounts are
//  switched on (flag `accounts`), an anonymous player is created for this install, and the player may link Sign in with Apple
//  (no scopes: no e-mail, no name) so progress and purchases follow them to another device. The session token lives in the
//  Keychain.
//

import Foundation

enum AccountState: Equatable {
    /// No player yet, or the backend is off.
    case signedOut
    /// A player exists for this install but isn't linked to an Apple account.
    case anonymous
    case linked
}

@MainActor
final class PlayerAccount: ObservableObject {

    static let shared = PlayerAccount()

    @Published private(set) var state: AccountState = .signedOut
    @Published private(set) var lastError: String?

    nonisolated private static let tokenAccount = "playerToken"
    private static let linkedKey = "backend_playerLinked"

    private let keychain: KeychainStore
    private let defaults: UserDefaults
    private let makeClient: (PlayerAccount) -> APIClient
    private let isEnabled: () -> Bool

    init(keychain: KeychainStore = KeychainStore(), defaults: UserDefaults = .standard,
         makeClient: ((PlayerAccount) -> APIClient)? = nil,
         isEnabled: @escaping () -> Bool = { BackendEnvironment.isEnabled && FeatureFlags.isOn(.accounts) }) {
        self.keychain = keychain
        self.defaults = defaults
        self.isEnabled = isEnabled
        self.makeClient = makeClient ?? { account in
            APIClient(authorization: { account.token }, onResponse: { response in
                // A token with about six months left comes back renewed: keep it.
                if let fresh = response.value(forHTTPHeaderField: "X-Refreshed-Token") { account.store(token: fresh) }
            })
        }
        refreshState()
    }

    nonisolated var token: String? { keychain.read(Self.tokenAccount) }

    nonisolated func store(token: String) {
        keychain.write(token, for: Self.tokenAccount)
    }

    private func refreshState() {
        if keychain.read(Self.tokenAccount) == nil { state = .signedOut }
        else { state = defaults.bool(forKey: Self.linkedKey) ? .linked : .anonymous }
    }

    // MARK: Anonymous player

    private struct Created: Decodable { let playerId: String; let token: String }
    private struct Linked: Decodable { let playerId: String; let token: String; let merged: Bool }
    private struct LinkRequest: Encodable { let provider: String; let identityToken: String }
    private struct Empty: Encodable {}

    /// Creates the anonymous player for this install once. A 409 means this install already has one whose token we lost (a
    /// reinstall): the player can sign in with Apple to get back in.
    func ensurePlayer() async {
        guard isEnabled(), token == nil else { return }
        do {
            let created: Created = try await makeClient(self).post("v1/players", body: Empty())
            store(token: created.token)
            refreshState()
            lastError = nil
        } catch {
            lastError = String(describing: error)
        }
    }

    // MARK: Sign in with Apple

    /// Sends the identity token Apple gave the app. If this Apple account already has a player (another device), the
    /// anonymous player is merged into it and the token of the surviving player replaces ours. Returns whether it worked.
    @discardableResult
    func linkApple(identityToken: String) async -> Bool {
        guard isEnabled() else { return false }
        if token == nil { await ensurePlayer() }
        do {
            let linked: Linked = try await makeClient(self).post("v1/players/link", body: LinkRequest(provider: "apple", identityToken: identityToken))
            store(token: linked.token)
            defaults.set(true, forKey: Self.linkedKey)
            refreshState()
            lastError = nil
            return true
        } catch {
            lastError = String(describing: error)
            return false
        }
    }

    /// Forgets the session on this device (progress stays on the server and on the device).
    func signOut() {
        keychain.delete(Self.tokenAccount)
        defaults.removeObject(forKey: Self.linkedKey)
        refreshState()
    }
}
