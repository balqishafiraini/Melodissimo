//
//  PlaySession.swift
//  Melodissimo
//

import Foundation

/// Whether a play screen is open. Background work that would stutter a song (the iCloud merge) waits for it
/// to end. Task S4 fills in the rest (auto-lock, counter).
enum PlaySession {
    static var isActive = false
}
