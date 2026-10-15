//
//  CoachMarks.swift
//  Melodissimo
//

import Foundation

/// The things on the first stage's screen that a coach-mark bubble can point at.
enum CoachTarget: String, Hashable, CaseIterable {
    /// The speech bubble holding the note to play.
    case question
    case keyboard
    /// The hearts, which turn into stars at the end.
    case hearts
}

/// One bubble of the first-stage tour: where it points and what it says.
struct CoachStep: Equatable {
    let target: CoachTarget
    /// An English key from `Localizable.strings`.
    let text: String
}

/// The three bubbles shown the first time a new player opens stage `c1-01`, right after the pre-play test.
enum CoachMarks {
    /// The stage a new player is taken to, which is also the one that shows the bubbles.
    static let firstStageId = "c1-01"
    static let seenId = "firstStage"

    static let firstStage: [CoachStep] = [
        CoachStep(target: .question, text: "These numbers are notes"),
        CoachStep(target: .keyboard, text: "Play the key that matches the note"),
        CoachStep(target: .hearts, text: "Hearts you keep become stars. Stars unlock the next stage."),
    ]

    /// Show the bubbles on the first stage only, only while it has no star yet and only once.
    static func shouldShow(stageId: String?, stars: Int, seen: Bool) -> Bool {
        stageId == firstStageId && stars == 0 && !seen
    }
}
