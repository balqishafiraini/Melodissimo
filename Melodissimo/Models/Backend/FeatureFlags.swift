//
//  FeatureFlags.swift
//  Melodissimo
//

import Foundation

/// The flags the app knows. A flag only gates code that already exists; it never adds a feature. Each has a code
/// default equal to today's behaviour, used when the server is unreachable or doesn't mention the flag.
enum FlagKey: String, CaseIterable {
    case shop
    case dailyChallenge
    case micInput
    case coinStore
    case reviveInDaily
    case packStore
    /// First-party usage events (Task B9). Off until the server switches it on.
    case analytics

    var defaultValue: Bool {
        switch self {
        case .shop, .dailyChallenge, .micInput, .coinStore: return true
        case .reviveInDaily, .packStore, .analytics: return false
        }
    }
}

enum FeatureFlags {
    /// The latest flags from the bootstrap (`LiveConfig`, set by `BootstrapService`); tests replace it.
    static var source: () -> [String: Bool] = { LiveConfig.flags }

    static func isOn(_ key: FlagKey) -> Bool {
        source()[key.rawValue] ?? key.defaultValue
    }
}
