//
//  PlayModels.swift
//  Melodissimo
//

import Foundation

/// How a song stage is played.
enum StageMode: String, Hashable, Codable {
    /// Autoplay: notes fall, keys light up and play. No input.
    case listen
    /// The song waits at the hit line until the right key is pressed. No score.
    case practice
    /// Real time, judged hits, combo and score.
    case perform
}
