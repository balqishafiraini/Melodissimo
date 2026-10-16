//
//  InstallID.swift
//  Melodissimo
//

import Foundation

/// A random id for this install, used only to spread rollouts evenly (`BACKEND_PLAN.md` D7). It is not a device
/// identifier and not tied to the player.
enum InstallID {
    static let key = "backend_installId"

    static func current(defaults: UserDefaults = .standard) -> String {
        if let stored = defaults.string(forKey: key), UUID(uuidString: stored) != nil { return stored }
        let made = UUID().uuidString
        defaults.set(made, forKey: key)
        return made
    }
}
