//
//  DailyChallenge.swift
//  Melodissimo
//

import Foundation

/// Today's challenge. It is built from the date alone, so every player gets the same one on the
/// same day: the type rotates on `dayOfYear % 3` and the questions come from a seed made of the date.
struct DailyChallenge: Equatable {

    enum Kind: Equatable {
        /// Clear five rounds of Echo.
        case echo
        /// A 15-question Note Battle with 4 seconds a note.
        case battle
        /// Perform the first 32 notes of a song at normal speed.
        case songSprint
    }

    static let echoRounds = 5
    static let battleQuestions = 15
    static let battleTimePerNote = 4.0
    static let sprintNotes = 32

    /// `yyyyMMdd`, e.g. `20261010`. Also the suffix of the `daily_done_<key>` flag.
    let dateKey: String
    /// The date key as a number.
    let seed: UInt64
    let kind: Kind
    /// Key ids of every note taught up to the player's chapter.
    let pool: [Int]
    /// Song sprint only: the song chosen for the day.
    let songId: String?

    // MARK: Building

    /// The date as `yyyyMMdd`, in the player's own calendar (a day is the player's local day).
    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Today's challenge for a player who is up to `chapter` of the tour (at least chapter 1).
    static func make(for date: Date, chapter: Int, calendar: Calendar = .current) -> DailyChallenge? {
        make(dateKey: dateKey(for: date, calendar: calendar), chapter: chapter, calendar: calendar)
    }

    /// The challenge for a date key, or `nil` when the key isn't a real date.
    static func make(dateKey: String, chapter: Int, calendar: Calendar = .current) -> DailyChallenge? {
        guard dateKey.count == 8, let number = UInt64(dateKey),
              let date = date(fromKey: dateKey, calendar: calendar),
              let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) else { return nil }

        let kind: Kind
        switch dayOfYear % 3 {
        case 0: kind = .echo
        case 1: kind = .battle
        default: kind = .songSprint
        }

        let safeChapter = min(max(chapter, 1), CampaignCatalog.chapters.count)
        let pool = CampaignCatalog.notesTaught(through: safeChapter)
        let songId = kind == .songSprint ? sprintSong(seed: number, pool: pool) : nil
        return DailyChallenge(dateKey: dateKey, seed: number, kind: kind, pool: pool, songId: songId)
    }

    private static func date(fromKey key: String, calendar: Calendar) -> Date? {
        guard let year = Int(key.prefix(4)),
              let month = Int(key.dropFirst(4).prefix(2)),
              let day = Int(key.suffix(2)) else { return nil }
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        guard let date = calendar.date(from: parts) else { return nil }
        // `date(from:)` rolls 31 February over into March; a real key reads back the same.
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return back.year == year && back.month == month && back.day == day ? date : nil
    }

    /// A song for the sprint, picked by the seed from the ones whose first notes only use notes the
    /// player has learned. Falls back to any song that isn't solemn when nothing fits yet.
    private static func sprintSong(seed: UInt64, pool: [Int]) -> String? {
        let allowed = Set(pool)
        let playable = SongLibrary.all.filter { !$0.isSolemn }
        let fitting = playable.filter { Set($0.keyIds.prefix(sprintNotes)).isSubset(of: allowed) }
        let candidates = fitting.isEmpty ? playable : fitting
        guard !candidates.isEmpty else { return nil }
        var generator = SeededRandom(seed: seed)
        return candidates[Int.random(in: 0..<candidates.count, using: &generator)].id
    }

    // MARK: Playing

    /// What to launch for this challenge, or `nil` if the sprint's song is missing.
    var playKind: PlayRequest.Kind? {
        switch kind {
        case .echo:
            return .echo(EchoConfig(pool: pool, roundsToClear: Self.echoRounds, startLength: 2,
                                    glowDuringPlayback: true, seed: seed))
        case .battle:
            return .battle(BattleConfig(newPool: pool, questionCount: Self.battleQuestions,
                                        timePerNote: Self.battleTimePerNote, seed: seed))
        case .songSprint:
            guard let songId else { return nil }
            return .song(songId: songId, mode: .perform, speed: 1, isBoss: false, isSolemn: false,
                         noteLimit: Self.sprintNotes)
        }
    }
}
