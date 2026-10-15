//
//  QuizConfig.swift
//  Melodissimo
//

import Foundation

/// The listening quizzes: the game plays a few notes, the player picks an answer from buttons.
enum QuizVariant: String, CaseIterable, Hashable, Codable {
    /// The opening of a song plays (with its rhythm); pick the title.
    case guessSong
    /// A phrase of a song plays with one note changed by Fals; tap the written note that sounded wrong.
    case spotFals
    /// Two notes play; is the second one higher, lower or the same?
    case higherLower
}

/// Settings for one quiz run.
struct QuizConfig: Hashable {
    var variant: QuizVariant
    var questionCount = 10
    var hearts = 3
    var seed: UInt64
    /// The songs Guess the Song and Spot Fals may use, by title. `nil` uses the whole library;
    /// tour stages pass only the songs the player has met so far.
    var songTitles: [String]? = nil
}

/// One question: what plays, and the answer buttons.
struct QuizQuestion: Hashable {
    /// The notes that sound, as key ids.
    let phrase: [Int]
    /// When each note of `phrase` starts, in seconds from the first note.
    let onsets: [Double]
    /// Button labels. Song titles and the higher / lower words are localization keys; note labels show as they are.
    let choices: [String]
    let correctIndex: Int
}

/// A song's notes with their timing, for the quizzes.
struct QuizSong: Hashable {
    let title: String
    let keyIds: [Int]
    /// Seconds from the first note.
    let onsets: [Double]
    let isSolemn: Bool

    /// Reads the song's chart (falling back to one note per beat) so the opening keeps its rhythm.
    static func from(_ song: Song) -> QuizSong {
        let chart = SongChart.load(for: song)
        let first = chart.notes.first.map { chart.seconds(atBeat: $0.b) } ?? 0
        return QuizSong(title: song.title,
                        keyIds: chart.notes.map(\.k),
                        onsets: chart.notes.map { chart.seconds(atBeat: $0.b) - first },
                        isSolemn: song.isSolemn)
    }
}

/// Builds quiz questions. Pure functions over a seeded generator, so a run is stable and testable.
enum QuizQuestionGenerator {

    /// The answer words of Higher or lower, in button order.
    static let higherLowerChoices = ["Higher", "Lower", "Same"]

    /// How much of a song's opening Guess the Song plays: the notes in the first few seconds, 5 to 8 of them.
    static let openingSeconds = 4.0
    static let openingNotes = 5...8

    /// Choices per Guess the Song question (the right title and three others).
    static let titleChoices = 4

    /// Spot Fals skips phrases longer than this, which crawl too slowly to hold in your head.
    static let maxPhraseSeconds = 5.0

    static func questions(for config: QuizConfig, songs: [QuizSong]) -> [QuizQuestion] {
        var rng = SeededRandom(seed: config.seed)
        let count = max(1, config.questionCount)
        switch config.variant {
        case .guessSong: return guessSong(songs: songs, count: count, using: &rng)
        case .spotFals: return spotFals(songs: songs, count: count, using: &rng)
        case .higherLower: return higherLower(count: count, using: &rng)
        }
    }

    // MARK: Guess the Song

    /// One song per question (no repeats until every song has had a turn), its opening, and three other titles.
    static func guessSong(songs: [QuizSong], count: Int, using rng: inout SeededRandom) -> [QuizQuestion] {
        let usable = songs.filter { $0.keyIds.count >= openingNotes.lowerBound }
        let titles = Array(Set(usable.map(\.title))).sorted()
        guard titles.count >= 2 else { return [] }

        var order: [QuizSong] = []
        var questions: [QuizQuestion] = []
        while questions.count < count {
            if order.isEmpty { order = usable.shuffled(using: &rng) }
            let song = order.removeLast()
            let length = openingLength(of: song)
            var choices = Array(titles.filter { $0 != song.title }.shuffled(using: &rng).prefix(titleChoices - 1)) + [song.title]
            choices.shuffle(using: &rng)
            questions.append(QuizQuestion(phrase: Array(song.keyIds.prefix(length)),
                                          onsets: Array(song.onsets.prefix(length)),
                                          choices: choices,
                                          correctIndex: choices.firstIndex(of: song.title)!))
        }
        return questions
    }

    /// The notes that start within `openingSeconds`, clamped to `openingNotes` and the song's length.
    static func openingLength(of song: QuizSong) -> Int {
        let inWindow = song.onsets.filter { $0 < openingSeconds }.count
        return min(song.keyIds.count, min(openingNotes.upperBound, max(openingNotes.lowerBound, inWindow)))
    }

    // MARK: Spot Fals's note

    /// A phrase from a song (never a national-symbol song: Fals stays away from those) with one note
    /// after the first moved a little. The buttons are the phrase as written; the answer is the changed position.
    /// Phrases are 5 notes long in the first half of the run and 6 after.
    static func spotFals(songs: [QuizSong], count: Int, using rng: inout SeededRandom) -> [QuizQuestion] {
        // Every phrase a song can give, by length, so a pick never has to be retried.
        func phrases(length: Int) -> [(song: QuizSong, start: Int)] {
            songs.filter { !$0.isSolemn }.flatMap { song -> [(song: QuizSong, start: Int)] in
                guard song.keyIds.count >= length else { return [] }
                return (0...(song.keyIds.count - length)).compactMap { start in
                    let span = song.onsets[start + length - 1] - song.onsets[start]
                    let notes = song.keyIds[start..<(start + length)]
                    return span <= maxPhraseSeconds && Set(notes).count > 1 ? (song, start) : nil
                }
            }
        }
        let byLength = [5: phrases(length: 5), 6: phrases(length: 6)]

        var questions: [QuizQuestion] = []
        for index in 0..<count {
            let length = index < count / 2 ? 5 : 6
            guard let pick = (byLength[length]!.isEmpty ? byLength[5]! : byLength[length]!).randomElement(using: &rng) else { break }
            let size = min(length, pick.song.keyIds.count - pick.start)
            let written = Array(pick.song.keyIds[pick.start..<(pick.start + size)])
            let onsets = pick.song.onsets[pick.start..<(pick.start + size)].map { $0 - pick.song.onsets[pick.start] }
            let position = Int.random(in: 1..<size, using: &rng)
            var played = written
            played[position] = falsNote(replacing: written[position], using: &rng)
            questions.append(QuizQuestion(phrase: played, onsets: onsets,
                                          choices: written.map { NoteCatalog.note($0).label },
                                          correctIndex: position))
        }
        return questions
    }

    /// A white key 1 to 4 semitones away from `keyId`: close enough to sound like a slip, far enough to hear.
    static func falsNote(replacing keyId: Int, using rng: inout SeededRandom) -> Int {
        let original = NoteCatalog.note(keyId).semitone
        let candidates = NoteCatalog.whiteKeyIDs.filter {
            (1...4).contains(abs(NoteCatalog.note($0).semitone - original))
        }
        return candidates.randomElement(using: &rng) ?? (keyId == 1 ? 2 : 1)
    }

    // MARK: Higher or lower

    /// Two notes from the middle of the keyboard (5. … 5˙). About one in five are the same note. In the
    /// first half of the run the notes are at least 4 semitones apart; later any gap goes.
    static func higherLower(count: Int, using rng: inout SeededRandom) -> [QuizQuestion] {
        let pool = Array(2...16)
        var questions: [QuizQuestion] = []
        for index in 0..<count {
            let first = pool.randomElement(using: &rng)!
            let minimumGap = index < count / 2 ? 4 : 1
            let second: Int
            if Int.random(in: 0..<5, using: &rng) == 0 {
                second = first
            } else {
                let base = NoteCatalog.note(first).semitone
                let others = pool.filter { abs(NoteCatalog.note($0).semitone - base) >= minimumGap }
                second = others.randomElement(using: &rng) ?? first
            }
            let a = NoteCatalog.note(first).semitone, b = NoteCatalog.note(second).semitone
            let answer = b > a ? 0 : (b < a ? 1 : 2)
            questions.append(QuizQuestion(phrase: [first, second], onsets: [0, 0.9],
                                          choices: higherLowerChoices, correctIndex: answer))
        }
        return questions
    }
}
