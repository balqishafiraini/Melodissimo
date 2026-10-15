//
//  StageScoreboard.swift
//  Melodissimo
//

import Foundation
import Combine

/// A press of a key that matched no note: the key and a counter that grows with every one, so the same key
/// pressed wrongly twice in a row is still a change.
struct WrongPress: Equatable {
    let keyId: Int
    let serial: Int
}

/// Everything on the stage that changes with each judgment: score, combo, the judgment counts, how many notes
/// have been judged. It is split off `RhythmEngine` so that only the small HUD views that show these numbers
/// observe it. When they lived on the engine, every hit re-evaluated the whole stage body, including the
/// 32-key keyboard, at the very moment the player needs the frame.
///
/// The engine owns one and is the only writer; views read it (`@ObservedObject` in the HUD) and the engine
/// exposes the same values through read-only pass-throughs.
final class StageScoreboard: ObservableObject {
    @Published private(set) var score = 0
    @Published private(set) var combo = 0
    @Published private(set) var maxCombo = 0
    @Published private(set) var counts = JudgmentCounts()
    @Published private(set) var wrongPresses = 0
    /// Notes hit or missed so far, for the progress bar. Listen's silent marking and Practice count too.
    @Published private(set) var judgedCount = 0
    /// The latest wrong press, so Practice can flash that key red.
    @Published private(set) var lastWrongPress: WrongPress?

    private var wrongSerial = 0

    func registerHit(_ judgment: Judgment, points: Int) {
        counts.add(judgment)
        combo += 1
        if combo > maxCombo { maxCombo = combo }
        score += points
        judgedCount += 1
    }

    func registerMisses(_ count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count { counts.add(.miss) }
        combo = 0
        judgedCount += count
    }

    /// A press that hit nothing. Perform loses the combo for it; Practice doesn't.
    func registerWrongPress(keyId: Int, breaksCombo: Bool) {
        wrongPresses += 1
        if breaksCombo { combo = 0 }
        wrongSerial += 1
        lastWrongPress = WrongPress(keyId: keyId, serial: wrongSerial)
    }

    /// A long note held to its tail: extra points, no change to the counts.
    func registerHoldBonus(points: Int) {
        score += points
    }

    /// A long note let go too early in Perform.
    func breakCombo() {
        combo = 0
    }

    /// A note judged without a score: a Practice hit, or a note Listen played.
    func noteJudged() {
        judgedCount += 1
    }

    func reset() {
        score = 0
        combo = 0
        maxCombo = 0
        counts = JudgmentCounts()
        wrongPresses = 0
        judgedCount = 0
        lastWrongPress = nil
    }
}
