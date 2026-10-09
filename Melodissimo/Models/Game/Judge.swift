//
//  Judge.swift
//  Melodissimo
//

import Foundation

enum Judgment: String, Codable, CaseIterable {
    case perfect, great, good, miss
}

/// How many notes landed in each judgment bucket.
struct JudgmentCounts: Hashable {
    var perfect = 0
    var great = 0
    var good = 0
    var miss = 0

    var total: Int { perfect + great + good + miss }

    mutating func add(_ judgment: Judgment) {
        switch judgment {
        case .perfect: perfect += 1
        case .great: great += 1
        case .good: good += 1
        case .miss: miss += 1
        }
    }

    func count(for judgment: Judgment) -> Int {
        switch judgment {
        case .perfect: return perfect
        case .great: return great
        case .good: return good
        case .miss: return miss
        }
    }
}

/// Kid-friendly timing windows and the scoring formulas for Perform mode.
enum Judge {
    static let perfect = 0.070
    static let great = 0.130
    static let good = 0.200

    /// Judges a press by its distance from the note time (seconds, early or late).
    /// `nil` means the press is too far from the note to count as a hit.
    static func judge(delta: Double) -> Judgment? {
        switch abs(delta) {
        case ...perfect: return .perfect
        case ...great: return .great
        case ...good: return .good
        default: return nil
        }
    }

    /// Base points for a hit, before the combo multiplier.
    static func points(for judgment: Judgment) -> Int {
        switch judgment {
        case .perfect: return 300
        case .great: return 200
        case .good: return 100
        case .miss: return 0
        }
    }

    /// `1 + min(combo / 10, 3)` (integer division): ×1 below 10, ×2 from 10, ×3 from 20, ×4 from 30.
    static func multiplier(forCombo combo: Int) -> Int {
        1 + min(max(combo, 0) / 10, 3)
    }

    /// `max(0, P×1 + G×0.75 + Good×0.4 − wrong×0.25) / total × 100`.
    static func accuracy(counts: JudgmentCounts, wrongPresses: Int, totalNotes: Int) -> Double {
        guard totalNotes > 0 else { return 0 }
        let weighted = Double(counts.perfect) + Double(counts.great) * 0.75 + Double(counts.good) * 0.4
            - Double(wrongPresses) * 0.25
        return max(0, weighted) / Double(totalNotes) * 100
    }

    /// ≥ 60 % → 1★, ≥ 80 % → 2★, ≥ 95 % → 3★.
    static func stars(forAccuracy accuracy: Double) -> Int {
        if accuracy >= 95 { return 3 }
        if accuracy >= 80 { return 2 }
        if accuracy >= 60 { return 1 }
        return 0
    }

    /// Slower playback earns fewer stars: at most 1★ at 0.5× and 2★ at 0.75×.
    static func starCap(forSpeed speed: Double) -> Int {
        if speed <= 0.5 { return 1 }
        if speed <= 0.75 { return 2 }
        return 3
    }
}
