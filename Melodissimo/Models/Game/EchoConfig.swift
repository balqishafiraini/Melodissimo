//
//  EchoConfig.swift
//  Melodissimo
//

import Foundation

/// Settings for an Echo (ear-training) round set: the game plays a phrase, the player plays it back.
struct EchoConfig: Hashable {
    /// Key ids the phrases are made from.
    var pool: [Int]
    /// How many rounds clear the stage; `nil` means endless.
    var roundsToClear: Int?
    var startLength = 2
    var maxLength = 8
    /// Easy: keys glow while the phrase plays. Hard: they don't.
    var glowDuringPlayback = true
    /// Later rounds take contiguous slices of real songs that fit inside `pool`.
    var useSongSnippets = false
    var hearts = 3
    var seed: UInt64
}

/// Builds Echo phrases. Pure functions over a seeded generator, so they are stable and testable.
enum EchoPhraseGenerator {

    /// `startLength + round / 2`, capped at `maxLength`: one more note every two rounds.
    static func length(forRound round: Int, startLength: Int, maxLength: Int) -> Int {
        min(maxLength, startLength + max(0, round) / 2)
    }

    /// Notes of the pool in pitch order, without duplicates.
    static func sortedPool(_ pool: [Int]) -> [Int] {
        Array(Set(pool)).sorted {
            let a = NoteCatalog.note($0).semitone, b = NoteCatalog.note($1).semitone
            return a == b ? $0 < $1 : a < b
        }
    }

    /// A melodic random walk over the pool: start at a random note, then move by at most two
    /// notes up or down in pitch order (repeating the same note at most twice in a row), never leaving the pool.
    static func randomWalk(pool: [Int], length: Int, using rng: inout SeededRandom) -> [Int] {
        let sorted = sortedPool(pool)
        guard !sorted.isEmpty, length > 0 else { return [] }
        var index = Int.random(in: 0..<sorted.count, using: &rng)
        var phrase = [sorted[index]]
        var previousStepWasZero = false
        while phrase.count < length {
            var steps = (-2...2).filter { sorted.indices.contains(index + $0) && !($0 == 0 && previousStepWasZero) }
            if steps.isEmpty { steps = [0] }    // a one-note pool can only repeat
            let step = steps.randomElement(using: &rng)!
            index += step
            previousStepWasZero = step == 0
            phrase.append(sorted[index])
        }
        return phrase
    }

    /// A random contiguous slice of one of the songs that uses only notes from the pool and
    /// more than one distinct note. `nil` if no song has such a slice.
    static func songSnippet(pool: [Int], length: Int, songs: [[Int]], using rng: inout SeededRandom) -> [Int]? {
        guard length > 0 else { return nil }
        let allowed = Set(pool)
        var candidates: [[Int]] = []
        for song in songs where song.count >= length {
            for start in 0...(song.count - length) {
                let slice = Array(song[start..<(start + length)])
                if Set(slice).count > 1, slice.allSatisfy(allowed.contains) {
                    candidates.append(slice)
                }
            }
        }
        return candidates.randomElement(using: &rng)
    }
}
