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
        case quiz(QuizConfig)
        case rush
        case daily(dateKey: String)
    }

    let kind: Kind
    var campaignStageId: String? = nil
    /// Song stages: show the note names on the keys. `nil` uses the mode's default
    /// (on for Practice, the setting for Perform).
    var showKeyLabels: Bool? = nil
    /// Set (to `yyyyMMdd`) when this play is the day's challenge. The mode in `kind` is what is played;
    /// the date says which day's reward it counts for.
    var dailyDateKey: String? = nil
}

extension PlayRequest {
    /// A coarse name for the kind of play, for analytics: `listen`, `practice`, `perform`, `battle`, `classic`, `echo`, `quiz`, `rush`, `daily`.
    var analyticsMode: String {
        switch kind {
        case .song(_, let mode, _, _, _, _): return mode.rawValue
        case .battle: return "battle"
        case .classic: return "classic"
        case .echo: return "echo"
        case .quiz: return "quiz"
        case .rush: return "rush"
        case .daily: return "daily"
        }
    }

    var analyticsSongId: String? {
        if case .song(let songId, _, _, _, _, _) = kind { return songId }
        return nil
    }

    /// The props every play event carries: mode, and the song and stage when there are some.
    var analyticsProps: [String: JSONValue] {
        var props: [String: JSONValue] = ["mode": .string(analyticsMode)]
        if let songId = analyticsSongId { props["songId"] = .string(songId) }
        if let stage = campaignStageId { props["stageId"] = .string(stage) }
        return props
    }
}

/// The outcome of one play, handed to `ResultRecorder` and the results screen.
struct PlayResult: Hashable {
    let request: PlayRequest
    let didWin: Bool
    /// 0...3, already speed-capped.
    var stars: Int
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
    /// Battles and Melody Rush: how many answers were right (Rush pays one coin per five).
    var correctCount = 0
    /// How many times the player paid to continue after the hearts ran out.
    var revivesUsed = 0
}

/// What a play earned, shown on the results screen.
struct RewardSummary: Hashable {
    var coins = 0
    var newStars = 0
    var isNewBest = false
    /// Titles of achievements unlocked by this play.
    var newAchievements: [String] = []
}
