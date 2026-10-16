//
//  Tuning.swift
//  Melodissimo
//

import Foundation

/// Numbers the server can change without an app update (coin rewards, revive prices, …). Every accessor takes a code
/// default; a missing key, a value of the wrong type or one outside the allowed range gives the default.
enum Tuning {
    /// The latest tuning values from the bootstrap (`LiveConfig`, set by `BootstrapService`); tests replace it.
    static var source: () -> [String: JSONValue] = { LiveConfig.tuning }

    static func int(_ key: String, default fallback: Int, range: ClosedRange<Int> = 0...1_000_000) -> Int {
        guard case .number(let value)? = source()[key], value == value.rounded(), value.isFinite,
              value >= Double(range.lowerBound), value <= Double(range.upperBound) else { return fallback }
        return Int(value)
    }

    static func double(_ key: String, default fallback: Double, range: ClosedRange<Double> = 0...1_000_000) -> Double {
        guard case .number(let value)? = source()[key], value.isFinite, range.contains(value) else { return fallback }
        return value
    }

    static func bool(_ key: String, default fallback: Bool) -> Bool {
        guard case .bool(let value)? = source()[key] else { return fallback }
        return value
    }

    /// The revive numbers, from the `revive.*` and `plus.*` keys.
    static func reviveRules(base: ReviveRules = .defaults) -> ReviveRules {
        var rules = base
        rules.coinCost = int("revive.coinCost", default: base.coinCost, range: 0...10_000)
        rules.heartsRestored = int("revive.heartsRestored", default: base.heartsRestored, range: 1...10)
        rules.maxPerRun = int("revive.maxPerRun", default: base.maxPerRun, range: 0...10)
        rules.starCap = int("revive.starCap", default: base.starCap, range: 0...3)
        rules.plusFreeRevivesPerRun = int("plus.freeRevivesPerRun", default: base.plusFreeRevivesPerRun, range: 0...10)
        rules.reviveInDaily = FeatureFlags.isOn(.reviveInDaily)
        return rules
    }
}
