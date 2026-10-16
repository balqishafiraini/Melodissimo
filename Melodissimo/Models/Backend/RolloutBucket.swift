//
//  RolloutBucket.swift
//  Melodissimo
//

import Foundation

/// A stable 0…99 slot for an install and a key: FNV-1a over the UTF-8 bytes of `installId:key`, modulo 100. The server
/// decides flags and releases with the same function (`rollout.ts`); the app uses it for analytics sampling (Task B9).
enum RolloutBucket {
    static func fnv1a32(_ text: String) -> UInt32 {
        var hash: UInt32 = 0x811c9dc5
        for byte in text.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return hash
    }

    static func bucket(installId: String, key: String) -> Int {
        Int(fnv1a32("\(installId):\(key)") % 100)
    }
}
