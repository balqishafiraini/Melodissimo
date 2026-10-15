//
//  CloudMerge.swift
//  Melodissimo
//

import Foundation

/// The conflict-free merge rules for mirroring progress to iCloud (§3.4 keys). Two devices that
/// merge each other's values in any order end up with the same result: numbers keep the larger
/// value, flags are OR-ed, owned shop items are unioned. Settings are preferences and never sync.
enum CloudMerge {
    enum Rule {
        /// Numbers (Int or Double): the larger wins. Scores, stars, coin totals, stats.
        case max
        /// Numbers where the earliest non-zero value wins (the day the tour was completed).
        case earliest
        /// Flags: true if either side is true.
        case or
        /// String lists: the union, sorted.
        case union
        /// A choice (equipped item): this device's choice stays; a missing one is taken from iCloud.
        case keepLocal
    }

    /// The streak keys travel together: the side that played last owns `currentStreak`.
    static let streakKeys: Set<String> = ["currentStreak", "lastPlayedDate"]

    private static let maxKeys: Set<String> = [
        "currentLevel", "bestCombo", "longestStreak", "campaign_grantedChapter",
        "coins_earnedTotal", "coins_spentTotal", "coins_purchasedTotal", "rush_highScore", "echo_highScore",
        "preplayScore", "postplayScore",
    ]
    private static let maxPrefixes = ["bestScore_", "song_bestScore_", "song_bestAccuracy_", "song_stars_", "stage_stars_", "stat_", "quiz_best_", "inv_gained_", "inv_used_"]
    private static let orKeys: Set<String> = ["isPreplayDone"]
    private static let orPrefixes = ["achievement_", "song_practiced_", "song_fullCombo_", "daily_done_", "story_seen_", "coach_seen_"]
    private static let keepLocalKeys: Set<String> = ["equip_keyboard", "equip_notes", "equip_outfit"]

    /// How a key is merged, or `nil` when it does not sync. `songTitles` are the legacy trophy flags.
    static func rule(for key: String, songTitles: Set<String>) -> Rule? {
        if key == "stat_tourCompletedAt" { return .earliest }
        if key == "shop_owned" || key == "iap_granted" { return .union }
        if keepLocalKeys.contains(key) { return .keepLocal }
        if maxKeys.contains(key) || maxPrefixes.contains(where: key.hasPrefix) { return .max }
        if orKeys.contains(key) || orPrefixes.contains(where: key.hasPrefix) || songTitles.contains(key) { return .or }
        return nil
    }

    /// Whether the key is mirrored to iCloud at all (streak keys have their own rule).
    static func isSynced(_ key: String, songTitles: Set<String>) -> Bool {
        streakKeys.contains(key) || rule(for: key, songTitles: songTitles) != nil
    }

    /// What each side must change to agree.
    struct Result {
        var local: [String: Any] = [:]
        var remote: [String: Any] = [:]
    }

    static func merge(local: [String: Any], remote: [String: Any], songTitles: Set<String>) -> Result {
        var result = Result()
        func record(_ key: String, _ merged: Any) {
            if !same(local[key], merged) { result.local[key] = merged }
            if !same(remote[key], merged) { result.remote[key] = merged }
        }

        // Streak: whoever played last owns the current streak and the date.
        if let winner = streakWinner(local: local, remote: remote) {
            for key in streakKeys { if let value = winner[key] { record(key, value) } }
        }

        for key in Set(local.keys).union(remote.keys) where !streakKeys.contains(key) {
            guard let rule = rule(for: key, songTitles: songTitles),
                  let merged = mergedValue(rule, local[key], remote[key]) else { continue }
            record(key, merged)
        }
        return result
    }

    // MARK: Pieces

    private static func streakWinner(local: [String: Any], remote: [String: Any]) -> [String: Any]? {
        let localDate = local["lastPlayedDate"] as? Date
        let remoteDate = remote["lastPlayedDate"] as? Date
        switch (localDate, remoteDate) {
        case (nil, nil): return nil
        case (_?, nil): return local
        case (nil, _?): return remote
        case let (l?, r?):
            if l != r { return l > r ? local : remote }
            // Same day: keep the longer streak.
            let ls = (local["currentStreak"] as? NSNumber)?.intValue ?? 0
            let rs = (remote["currentStreak"] as? NSNumber)?.intValue ?? 0
            return ls >= rs ? local : remote
        }
    }

    private static func mergedValue(_ rule: Rule, _ local: Any?, _ remote: Any?) -> Any? {
        switch rule {
        case .max:
            switch (local as? NSNumber, remote as? NSNumber) {
            case let (l?, r?): return r.doubleValue > l.doubleValue ? r : l
            case let (l?, nil): return l
            case let (nil, r?): return r
            default: return nil
            }
        case .earliest:
            let l = (local as? NSNumber).flatMap { $0.doubleValue > 0 ? $0 : nil }
            let r = (remote as? NSNumber).flatMap { $0.doubleValue > 0 ? $0 : nil }
            switch (l, r) {
            case let (l?, r?): return r.doubleValue < l.doubleValue ? r : l
            case let (l?, nil): return l
            case let (nil, r?): return r
            default: return nil
            }
        case .or:
            guard local != nil || remote != nil else { return nil }
            return (local as? NSNumber)?.boolValue == true || (remote as? NSNumber)?.boolValue == true
        case .union:
            let l = local as? [String] ?? [], r = remote as? [String] ?? []
            guard local != nil || remote != nil else { return nil }
            return Array(Set(l).union(r)).sorted()
        case .keepLocal:
            return (local as? String) ?? (remote as? String)
        }
    }

    /// Value equality across the property-list types the two stores hold. A missing value is never "same".
    private static func same(_ a: Any?, _ b: Any) -> Bool {
        guard let a else { return false }
        if let a = a as? [String], let b = b as? [String] { return a == b }
        if let a = a as? NSNumber, let b = b as? NSNumber {
            // A flag and a number with the same value are not the same stored type.
            return CFGetTypeID(a) == CFGetTypeID(b) && a == b
        }
        return (a as? NSObject)?.isEqual(b) ?? false
    }
}
