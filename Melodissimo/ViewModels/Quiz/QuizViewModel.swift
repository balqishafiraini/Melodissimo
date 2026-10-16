//
//  QuizViewModel.swift
//  Melodissimo
//

import Foundation
import Combine
import QuartzCore

/// Runs the listening quizzes (Guess the Song, Spot Fals's note, Higher or lower).
///
/// Flow per question: `listening` (the notes play at their onsets) → `answering` → `feedback`
/// (right, or a heart lost and the right answer shown) → the next question, until every question is
/// answered (`won`) or the hearts run out (`lost`). The player may answer while the notes still play,
/// and replay them as often as they like. Like Echo it never reads the clock: time-based methods take `now`.
final class QuizViewModel: ObservableObject {

    enum Phase: Hashable {
        case ready
        /// The notes are playing; `index` is the one sounding now (-1 during the lead-in).
        case listening(index: Int)
        case answering
        /// The player chose `chosen`; it was right or wrong.
        case feedback(chosen: Int, isCorrect: Bool)
        /// Out of hearts with a revive on offer: waiting for the player to continue or give up.
        case awaitingContinue
        case won
        case lost
    }

    static let leadIn = 0.4
    /// How long a note sounds after the last onset before the player's turn.
    static let tail = 0.6
    static let pauseAfterCorrect = 1.0
    /// Longer, so the right answer can be read.
    static let pauseAfterWrong = 1.8

    let config: QuizConfig
    /// The run's revive state, or `nil` when the run can't be revived.
    let reviveRun: ReviveRun?
    let questions: [QuizQuestion]

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var hearts: Int
    @Published private(set) var questionIndex = 0
    @Published private(set) var correctCount = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestStreak = 0

    private var playbackOrigin: CFTimeInterval = 0
    private var nextToPlay = 0
    private var soundingKey: Int?
    private var resumeAt: CFTimeInterval = 0

    private let soundPlayer: (String) -> Void
    private let soundStopper: (String) -> Void

    init(config: QuizConfig,
         reviveRun: ReviveRun? = nil,
         songs: [QuizSong] = SongLibrary.all.map(QuizSong.from),
         soundPlayer: @escaping (String) -> Void = { playSound(key: $0) },
         soundStopper: @escaping (String) -> Void = { stopSound(key: $0) }) {
        self.config = config
        self.reviveRun = reviveRun
        let pool = config.songTitles.map { titles in songs.filter { titles.contains($0.title) } } ?? songs
        self.questions = QuizQuestionGenerator.questions(for: config, songs: pool)
        self.hearts = config.hearts
        self.soundPlayer = soundPlayer
        self.soundStopper = soundStopper
    }

    // MARK: Derived values

    var question: QuizQuestion? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
    }

    /// Hearts left when the run is won, 0 otherwise.
    var stars: Int {
        guard phase == .won else { return 0 }
        let earned = min(max(hearts, 0), 3)
        return reviveRun?.cappedStars(earned) ?? earned
    }

    var canAnswer: Bool {
        switch phase {
        case .listening, .answering: return true
        default: return false
        }
    }

    var canReplay: Bool {
        phase == .answering
    }

    // MARK: Play

    func start(now: CFTimeInterval) {
        guard phase == .ready else { return }
        guard !questions.isEmpty else { phase = .lost; return }
        beginPlayback(now: now)
    }

    /// Plays the current question's notes again.
    func replay(now: CFTimeInterval) {
        guard canReplay else { return }
        beginPlayback(now: now)
    }

    func answer(_ choice: Int, now: CFTimeInterval) {
        guard canAnswer, let question else { return }
        stopSounding()
        let isCorrect = choice == question.correctIndex
        if isCorrect {
            correctCount += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            resumeAt = now + QuizViewModel.pauseAfterCorrect
        } else {
            streak = 0
            hearts = max(0, hearts - 1)
            resumeAt = now + QuizViewModel.pauseAfterWrong
        }
        phase = .feedback(chosen: choice, isCorrect: isCorrect)
    }

    /// Advances playback and the pause after an answer. Call every frame (or at 20 Hz).
    func step(now: CFTimeInterval) {
        switch phase {
        case .listening:
            stepPlayback(now: now)
        case .feedback:
            guard now >= resumeAt else { return }
            if hearts == 0 {
                phase = reviveRun.map { $0.options.isEmpty } == false ? .awaitingContinue : .lost
            } else {
                moveOn(now: now)
            }
        case .ready, .answering, .awaitingContinue, .won, .lost:
            break
        }
    }

    private func moveOn(now: CFTimeInterval) {
        if questionIndex + 1 >= questions.count {
            phase = .won
        } else {
            questionIndex += 1
            beginPlayback(now: now)
        }
    }

    // MARK: Revive

    /// Continues after the hearts ran out: pays, restores hearts and goes on to the next question. `false`, changing
    /// nothing, when it isn't offered or can't be paid.
    @discardableResult
    func revive(_ source: ReviveSource, now: CFTimeInterval) -> Bool {
        guard phase == .awaitingContinue, let run = reviveRun, run.perform(source) else { return false }
        hearts = run.rules.heartsRestored
        moveOn(now: now)
        return true
    }

    /// The player chose not to continue.
    func giveUp() {
        guard phase == .awaitingContinue else { return }
        phase = .lost
    }

    /// Ends the note that is sounding. Call when the screen goes away mid-playback.
    func silence() {
        stopSounding()
    }

    // MARK: Playback

    private func beginPlayback(now: CFTimeInterval) {
        stopSounding()
        playbackOrigin = now + QuizViewModel.leadIn
        nextToPlay = 0
        phase = .listening(index: -1)
    }

    private func stepPlayback(now: CFTimeInterval) {
        guard let question else { return }
        while nextToPlay < question.phrase.count, now >= playbackOrigin + question.onsets[nextToPlay] {
            stopSounding()
            let key = question.phrase[nextToPlay]
            soundPlayer(NoteCatalog.note(key).sound)
            soundingKey = key
            phase = .listening(index: nextToPlay)
            nextToPlay += 1
        }
        if nextToPlay >= question.phrase.count,
           now >= playbackOrigin + (question.onsets.last ?? 0) + QuizViewModel.tail {
            stopSounding()
            phase = .answering
        }
    }

    private func stopSounding() {
        guard let key = soundingKey else { return }
        soundStopper(NoteCatalog.note(key).sound)
        soundingKey = nil
    }
}
