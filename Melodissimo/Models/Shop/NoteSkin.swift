//
//  NoteSkin.swift
//  Melodissimo
//

import Foundation

/// How the falling notes of a song stage are coloured. Models don't import SwiftUI, so a colour is
/// described as hue, saturation and brightness (all 0...1) for the view to turn into a `Color`.
enum NoteSkin: Equatable {
    /// Yellow notes on the white keys, navy on the black keys.
    case standard
    /// A hue for every pitch class, so the same note has the same colour in every octave.
    case rainbow
    /// Glowing cyan on the white keys, magenta on the black keys.
    case neon

    struct Fill: Equatable {
        let hue: Double
        let saturation: Double
        let brightness: Double
    }

    /// The skin that goes with a shop item id (`notes_rainbow`, ...); anything else is the standard look.
    init(itemId: String) {
        switch itemId {
        case "notes_rainbow": self = .rainbow
        case "notes_neon": self = .neon
        default: self = .standard
        }
    }

    /// The colour of a note on the key with this pitch order (`Note.semitone`), or `nil` for the standard look.
    func fill(semitone: Int, isBlack: Bool) -> Fill? {
        switch self {
        case .standard:
            return nil
        case .rainbow:
            let pitchClass = ((semitone % 12) + 12) % 12
            // Black keys are a shade deeper so they still read as the sharps.
            return Fill(hue: Double(pitchClass) / 12,
                        saturation: isBlack ? 0.9 : 0.7,
                        brightness: isBlack ? 0.8 : 1)
        case .neon:
            return isBlack ? Fill(hue: 0.88, saturation: 0.85, brightness: 1)
                           : Fill(hue: 0.5, saturation: 0.8, brightness: 1)
        }
    }
}
