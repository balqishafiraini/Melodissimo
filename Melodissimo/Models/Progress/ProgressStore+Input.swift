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
        get {
            #if DEBUG
            // `-qaInputMode pianika` (QA scripts): this launch only, nothing is stored.
            if defaults === UserDefaults.standard, let forced = UserDefaults.standard.string(forKey: "qaInputMode"),
               let mode = InputMode(rawValue: forced) { return mode }
            #endif
            return InputMode(rawValue: defaults.string(forKey: "settings_inputMode") ?? "") ?? .touch
        }
        set {
            defaults.set(newValue.rawValue, forKey: "settings_inputMode")
            objectWillChange.send()
        }
    }
}
