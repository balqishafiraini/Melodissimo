//
//  Revive.swift
//  Melodissimo
//
//  The "Lanjut?" rules (`BACKEND_PLAN.md` §5.4): when the hearts reach 0 the player may pay to go on. All of the
//  numbers are tunable; the defaults below are what the app uses offline.
//

import Foundation

/// How a revive is paid.
enum ReviveSource: String, Hashable {
    /// One of the player's heart items.
    case heart
    /// Coins from the balance.
    case coins
    /// A free revive that Melodissimo Plus members get each run.
    case plus
}

/// The tunable numbers behind a revive. `Tuning` overrides these once the backend is wired (Task B5.2).
struct ReviveRules: Equatable {
    var coinCost = 50
    var heartsRestored = 1
    var maxPerRun = 2
    /// The most stars a won run can earn after using a revive.
    var starCap = 1
    var plusFreeRevivesPerRun = 1
    /// Whether the Daily Challenge offers revives (flag `reviveInDaily`, off by default).
    var reviveInDaily = false

    static let defaults = ReviveRules()
    /// The inventory item a heart revive uses.
    static let heartItemId = "boost_heart"
}

/// One way to continue, as the "Lanjut?" sheet shows it.
struct ReviveOption: Hashable {
    let source: ReviveSource
    /// Coins it costs (0 unless `source == .coins`).
    let cost: Int
    /// False when the player can't pay now (not enough coins); the sheet then sends them to the shop.
    let isAffordable: Bool
}

/// What a revive needs from the player's belongings. `ProgressStore` is the real one.
protocol ReviveWallet: AnyObject {
    var reviveHeartCount: Int { get }
    var reviveBalance: Int { get }
    /// Uses one heart item. `false` when there is none.
    func useReviveHeart() -> Bool
    /// Spends coins. `false` when the balance is short.
    func spendReviveCoins(_ amount: Int) -> Bool
}

enum Revive {

    /// Whether the player is a Melodissimo Plus member. Task B7.2 replaces this with the real entitlement.
    static var isPlusMember: () -> Bool = { false }

    /// The options to offer when the hearts hit 0. Empty means: no revive, the run is lost.
    static func options(rules: ReviveRules, revivesUsed: Int, plusFreeUsed: Int, isPlus: Bool,
                        heartCount: Int, balance: Int, isDaily: Bool) -> [ReviveOption] {
        if isDaily && !rules.reviveInDaily { return [] }
        guard revivesUsed < rules.maxPerRun else { return [] }
        // A Plus member's free revives come first and are the only thing shown while any are left.
        if isPlus, plusFreeUsed < rules.plusFreeRevivesPerRun {
            return [ReviveOption(source: .plus, cost: 0, isAffordable: true)]
        }
        var out: [ReviveOption] = []
        if heartCount > 0 { out.append(ReviveOption(source: .heart, cost: 0, isAffordable: true)) }
        out.append(ReviveOption(source: .coins, cost: rules.coinCost, isAffordable: balance >= rules.coinCost))
        return out
    }

    /// A won run that used a revive earns at most `starCap` stars.
    static func cappedStars(_ stars: Int, revivesUsed: Int, rules: ReviveRules) -> Int {
        revivesUsed > 0 ? min(stars, rules.starCap) : stars
    }

    /// Melody Rush scores from revived runs count for the local high score only.
    static func countsForLeaderboard(revivesUsed: Int) -> Bool {
        revivesUsed == 0
    }
}

/// The revive state of one run: how many were used and what the player can still do. A game view model holds one.
final class ReviveRun {
    let rules: ReviveRules
    let isDaily: Bool
    private let isPlus: Bool
    private let wallet: ReviveWallet
    /// Called after each successful revive (analytics, Task B9).
    var onRevive: ((ReviveSource) -> Void)?

    private(set) var revivesUsed = 0
    private(set) var plusFreeUsed = 0

    init(rules: ReviveRules = .defaults, isDaily: Bool, isPlus: Bool, wallet: ReviveWallet) {
        self.rules = rules
        self.isDaily = isDaily
        self.isPlus = isPlus
        self.wallet = wallet
    }

    var wasRevived: Bool { revivesUsed > 0 }

    /// The options now, from the run so far and what the player holds.
    var options: [ReviveOption] {
        Revive.options(rules: rules, revivesUsed: revivesUsed, plusFreeUsed: plusFreeUsed, isPlus: isPlus,
                       heartCount: wallet.reviveHeartCount, balance: wallet.reviveBalance, isDaily: isDaily)
    }

    /// Pays for the revive and counts it. Pays exactly once, or not at all (`false`) when the source isn't on offer
    /// or can't be paid.
    @discardableResult
    func perform(_ source: ReviveSource) -> Bool {
        guard let option = options.first(where: { $0.source == source }), option.isAffordable else { return false }
        switch source {
        case .plus: plusFreeUsed += 1
        case .heart: guard wallet.useReviveHeart() else { return false }
        case .coins: guard wallet.spendReviveCoins(option.cost) else { return false }
        }
        revivesUsed += 1
        onRevive?(source)
        return true
    }

    func cappedStars(_ stars: Int) -> Int {
        Revive.cappedStars(stars, revivesUsed: revivesUsed, rules: rules)
    }
}

extension ProgressStore: ReviveWallet {
    var reviveHeartCount: Int { inventoryCount(ReviveRules.heartItemId) }
    var reviveBalance: Int { coinBalance }
    func useReviveHeart() -> Bool { useFromInventory(ReviveRules.heartItemId) }
    func spendReviveCoins(_ amount: Int) -> Bool { spend(amount) }
}

extension ReviveRun {
    /// The revive state for a play launched from `request`, with the real wallet and Plus status.
    static func forPlay(_ request: PlayRequest, rules: ReviveRules = Tuning.reviveRules()) -> ReviveRun {
        ReviveRun(rules: rules, isDaily: request.dailyDateKey != nil, isPlus: Revive.isPlusMember(), wallet: ProgressStore.shared)
    }
}
