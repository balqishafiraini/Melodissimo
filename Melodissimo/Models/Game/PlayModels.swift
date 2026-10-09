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

/// What to play. One route (`.play`) launches any mode; `campaignStageId` routes the result back to the map.
struct PlayRequest: Hashable {
    enum Kind: Hashable {
        case song(songId: String, mode: StageMode, speed: Double, isBoss: Bool, isSolemn: Bool, noteLimit: Int?)
        case battle(BattleConfig)
        /// The old 100-level grid, rendered by the battle screen.
        case classic(levelNo: Int)
        case echo(EchoConfig)
        case rush
        case daily(dateKey: String)
    }

    let kind: Kind
    var campaignStageId: String? = nil
    /// Song stages: show the note names on the keys. `nil` uses the mode's default
    /// (on for Practice, the setting for Perform).
    var showKeyLabels: Bool? = nil
}

/// The outcome of one play, handed to `ResultRecorder` and the results screen.
struct PlayResult: Hashable {
    let request: PlayRequest
    let didWin: Bool
    /// 0...3, already speed-capped.
    let stars: Int
    let score: Int
    /// Songs only.
    let accuracy: Double?
    let maxCombo: Int
    /// Judgment counts; zeros for non-song modes.
    let perfect: Int
    let great: Int
    let good: Int
    let miss: Int
    let wrong: Int
}

/// What a play earned, shown on the results screen.
struct RewardSummary: Hashable {
    var coins = 0
    var newStars = 0
    var isNewBest = false
    /// Titles of achievements unlocked by this play.
    var newAchievements: [String] = []
}
