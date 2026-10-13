//
//  ProgressStore+Input.swift
//  Melodissimo
//

import Foundation

/// How the player plays the stages: on the screen, or on a real pianika heard by the microphone.
enum InputMode: String, CaseIterable {
    case touch, pianika
}

extension ProgressStore {
    /// `settings_inputMode`: `touch` (default) or `pianika`.
    var inputMode: InputMode {
        get { InputMode(rawValue: defaults.string(forKey: "settings_inputMode") ?? "") ?? .touch }
        set {
            defaults.set(newValue.rawValue, forKey: "settings_inputMode")
            objectWillChange.send()
        }
    }
}
