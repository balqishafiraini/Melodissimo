//
//  EchoViewModel.swift
//  Melodissimo
//

import Foundation
import Combine
import QuartzCore

/// Runs Echo, the ear-training mode: the game plays a short phrase, the player plays it back.
///
/// Flow: `listening` (the phrase plays, one note per `noteInterval`) → `yourTurn` → `roundCleared`
/// (a longer phrase follows) or `mistake` (a heart is lost and the same phrase replays), until the
/// stage is `won` or the hearts run out (`lost`). Like the other game logic, it never reads the clock:
/// every time-based method takes `now`, and the sound output is injectable.
final class EchoViewModel: ObservableObject {

    enum Phase: Hashable {
        case ready
        /// The phrase is playing; `index` is the note sounding now (-1 during the short lead-in).
        case listening(index: Int)
        /// The player is repeating the phrase; `progress` notes are already right.
        case yourTurn(progress: Int)
        case roundCleared
        case mistake
        case won
        case lost
    }

    /// What the player's last key did, so the view can flash it green (and show the label) or red.
    struct Outcome: Hashable {
        enum Kind: Hashable { case correct, wrong }
        let kind: Kind
        let keyId: Int
        /// Increases with every outcome so repeated equal outcomes still change the value.
        let token: Int
    }

    /// One note every 0.6 s while the phrase plays.
    static let noteInterval = 0.6
    /// A short pause before the first note, so the player is ready to listen.
    static let leadIn = 0.5
    /// How long the "round cleared" and "mistake" states last before the next phrase.
    static let pauseAfterRound = 0.8
    static let pauseAfterMistake = 0.8

    let config: EchoConfig

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var hearts: Int
    @Published private(set) var roundsCleared = 0
    /// The current phrase, as key ids.
    @Published private(set) var phrase: [Int] = []
    /// The key to light up while the phrase plays (`nil` when glow is off, as on Hard).
    @Published private(set) var glowKeyId: Int?
    @Published private(set) var lastOutcome: Outcome?

    private let pool: [Int]
    private let songs: [[Int]]
    private var random: SeededRandom
    private var playbackOrigin: CFTimeInterval = 0
    private var nextToPlay = 0
    private var soundingIndex: Int?
    private var resumeAt: CFTimeInterval = 0
    private var outcomeCounter = 0

    private let soundPlayer: (String) -> Void
    private let soundStopper: (String) -> Void

    init(config: EchoConfig,
         songs: [[Int]] = SongLibrary.all.map(\.keyIds),
         soundPlayer: @escaping (String) -> Void = { playSound(key: $0) },
         soundStopper: @escaping (String) -> Void = { stopSound(key: $0) }) {
        self.config = config
        self.pool = config.pool.isEmpty ? NoteCatalog.whiteKeyIDs : config.pool
        self.songs = songs
        self.hearts = config.hearts
        self.random = SeededRandom(seed: config.seed)
        self.soundPlayer = soundPlayer
        self.soundStopper = soundStopper
    }

    // MARK: Derived values

    var isEndless: Bool { config.roundsToClear == nil }

    /// Hearts left when the stage is cleared, 0 otherwise.
    var stars: Int {
        phase == .won ? min(max(hearts, 0), 3) : 0
    }

    /// Length of the phrase for the round being played.
    var currentPhraseLength: Int {
        EchoPhraseGenerator.length(forRound: roundsCleared, startLength: config.startLength, maxLength: config.maxLength)
    }

    // MARK: Play

    /// Starts the first round. Does nothing once the game is under way.
    func start(now: CFTimeInterval) {
        guard phase == .ready else { return }
        beginRound(now: now)
    }

    /// The player played a key. Only counts while it is their turn.
    func answer(keyId: Int, now: CFTimeInterval) {
        guard case .yourTurn(let progress) = phase, phrase.indices.contains(progress) else { return }
        if keyId == phrase[progress] {
            emit(.correct, keyId: keyId)
            if progress + 1 < phrase.count {
                phase = .yourTurn(progress: progress + 1)
            } else {
                roundsCleared += 1
                if let goal = config.roundsToClear, roundsCleared >= goal {
                    phase = .won
                } else {
                    phase = .roundCleared
                    resumeAt = now + EchoViewModel.pauseAfterRound
                }
            }
        } else {
            emit(.wrong, keyId: keyId)
            hearts = max(0, hearts - 1)
            if hearts == 0 {
                phase = .lost
            } else {
                phase = .mistake
                resumeAt = now + EchoViewModel.pauseAfterMistake
            }
        }
    }

    /// Advances playback and the pauses between rounds. Call every frame (or at 20 Hz).
    func step(now: CFTimeInterval) {
        switch phase {
        case .listening:
            stepPlayback(now: now)
        case .roundCleared:
            if now >= resumeAt { beginRound(now: now) }
        case .mistake:
            if now >= resumeAt { beginPlayback(now: now) }   // same phrase again
        case .ready, .yourTurn, .won, .lost:
            break
        }
    }

    // MARK: Rounds and playback

    private func beginRound(now: CFTimeInterval) {
        phrase = makePhrase(round: roundsCleared)
        beginPlayback(now: now)
    }

    private func beginPlayback(now: CFTimeInterval) {
        playbackOrigin = now + EchoViewModel.leadIn
        nextToPlay = 0
        soundingIndex = nil
        glowKeyId = nil
        phase = .listening(index: -1)
    }

    private func stepPlayback(now: CFTimeInterval) {
        while nextToPlay < phrase.count, now >= playbackOrigin + Double(nextToPlay) * EchoViewModel.noteInterval {
            stopSounding()
            let key = phrase[nextToPlay]
            soundPlayer(NoteCatalog.note(key).sound)
            soundingIndex = nextToPlay
            glowKeyId = config.glowDuringPlayback ? key : nil
            phase = .listening(index: nextToPlay)
            nextToPlay += 1
        }
        if nextToPlay >= phrase.count, now >= playbackOrigin + Double(phrase.count) * EchoViewModel.noteInterval {
            stopSounding()
            glowKeyId = nil
            phase = .yourTurn(progress: 0)
        }
    }

    private func stopSounding() {
        guard let index = soundingIndex, phrase.indices.contains(index) else { return }
        soundStopper(NoteCatalog.note(phrase[index]).sound)
        soundingIndex = nil
    }

    /// Later rounds can use a slice of a real song; otherwise (and as a fallback) a melodic random walk.
    private func makePhrase(round: Int) -> [Int] {
        let length = EchoPhraseGenerator.length(forRound: round, startLength: config.startLength, maxLength: config.maxLength)
        if config.useSongSnippets, round >= 2, round % 2 == 0,
           let snippet = EchoPhraseGenerator.songSnippet(pool: pool, length: length, songs: songs, using: &random) {
            return snippet
        }
        return EchoPhraseGenerator.randomWalk(pool: pool, length: length, using: &random)
    }

    private func emit(_ kind: Outcome.Kind, keyId: Int) {
        outcomeCounter += 1
        lastOutcome = Outcome(kind: kind, keyId: keyId, token: outcomeCounter)
    }
}
