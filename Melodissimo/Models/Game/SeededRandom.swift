//
//  SeededRandom.swift
//  Melodissimo
//

import Foundation

/// A small deterministic random generator (SplitMix64). The same seed always produces the
/// same sequence, so campaign stages and the daily challenge are stable and testable.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// A stable 64-bit hash of a string (FNV-1a). Swift's `hashValue` changes between launches,
    /// so use this to derive a seed from something like a stage id.
    static func seed(from string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
