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

    var defaultValue: Bool {
        switch self {
        case .shop, .dailyChallenge, .micInput, .coinStore: return true
        case .reviveInDaily, .packStore: return false
        }
    }
}

enum FeatureFlags {
    /// The latest flags from the bootstrap. `BootstrapService` sets this; tests set it directly.
    static var source: () -> [String: Bool] = { [:] }

    static func isOn(_ key: FlagKey) -> Bool {
        source()[key.rawValue] ?? key.defaultValue
    }
}
