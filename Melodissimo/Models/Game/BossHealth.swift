//
//  BossHealth.swift
//  Melodissimo
//

import Foundation

/// A song boss's health bar during a Perform run.
enum BossHealth {
    /// Starts at 1 and falls as notes are hit, by the same judgment weights the accuracy uses
    /// (Perfect 1, Great 0.75, Good 0.4) over all the song's notes: `1 − weighted hits / total`.
    /// Misses and wrong presses leave it alone, so it never goes back up.
    static func fraction(counts: JudgmentCounts, totalNotes: Int) -> Double {
        guard totalNotes > 0 else { return 1 }
        let hitShare = Judge.accuracy(counts: counts, wrongPresses: 0, totalNotes: totalNotes) / 100
        return min(1, max(0, 1 - hitShare))
    }

    /// The health at which the boss counts as beaten: 60 % accuracy is the first star.
    static let defeatFraction = 0.4
}
