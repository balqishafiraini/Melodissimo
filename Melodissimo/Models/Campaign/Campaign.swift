//
//  Campaign.swift
//  Melodissimo
//

import Foundation

/// One island of the Nusantara Tour. Each chapter teaches a few new notes and uses only
/// notes taught so far, so the curriculum gets harder island by island.
struct Chapter: Identifiable, Hashable {
    let number: Int
    let name: String
    /// Key ids introduced here, in the order they are taught.
    let newNotes: [Int]
    let songTitles: [String]
    let bossSongTitle: String
    /// Chapter 6 ends with the national anthem as a solemn ceremony.
    let finaleSongTitle: String?
    /// Seconds per note in this chapter's battles; `nil` means no timer.
    let timer: Double?
    /// SF Symbol shown on the map.
    let symbol: String
    /// 0xRRGGBB, converted to a `Color` by the views (models don't import SwiftUI).
    let tintHex: UInt32

    var id: Int { number }
}

/// A stage on the map. Stages are generated from the chapters, never hand-written.
struct Stage: Identifiable, Hashable {
    enum Kind: Hashable {
        case battle(BattleConfig)
        case echo(EchoConfig)
        case song(songId: String)
        case boss(songId: String)
        case finale(songId: String)
    }

    /// `c{chapter}-{index:02}`, e.g. `c2-05`.
    let id: String
    let chapter: Int
    /// 1-based position within the chapter.
    let index: Int
    let kind: Kind
}

enum CampaignCatalog {

    static let chapters: [Chapter] = [
        Chapter(number: 1, name: "Sumatra",
                newNotes: [5, 6, 7, 8, 9, 10, 11, 12],
                songTitles: ["Berkibarlah Benderaku"], bossSongTitle: "Terima Kasih Guru", finaleSongTitle: nil,
                timer: nil, symbol: "leaf.fill", tintHex: 0x27AE60),
        Chapter(number: 2, name: "Jawa",
                newNotes: [4, 3, 2],
                songTitles: ["Merah Putih", "Ibu Kita Kartini", "Ibu Pertiwi"], bossSongTitle: "Garuda Pancasila", finaleSongTitle: nil,
                timer: 6, symbol: "building.columns.fill", tintHex: 0xC0392B),
        Chapter(number: 3, name: "Kalimantan",
                newNotes: [1, 13, 14],
                songTitles: ["Halo Halo Bandung", "Indonesia Tetap Merdeka"], bossSongTitle: "Hari Merdeka", finaleSongTitle: nil,
                timer: 5, symbol: "tree.fill", tintHex: 0x117A65),
        Chapter(number: 4, name: "Sulawesi",
                newNotes: [15, 16, 17],
                songTitles: ["Tanah Airku", "Satu Nusa Satu Bangsa", "Maju Tak Gentar"], bossSongTitle: "Rayuan Pulau Kelapa", finaleSongTitle: nil,
                timer: 4.5, symbol: "sailboat.fill", tintHex: 0x2980B9),
        Chapter(number: 5, name: "Bali & Nusa Tenggara",
                newNotes: [25, 23, 26, 24, 27],
                songTitles: ["Mengheningkan Cipta", "Indonesia Pusaka"], bossSongTitle: "Hymne Guru", finaleSongTitle: nil,
                timer: 4, symbol: "sun.max.fill", tintHex: 0xE67E22),
        Chapter(number: 6, name: "Maluku & Papua",
                newNotes: [18, 19, 20, 21, 22, 28, 29, 30, 31, 32],
                songTitles: [], bossSongTitle: "Dari Sabang Sampai Merauke", finaleSongTitle: "Indonesia Raya",
                timer: 3.5, symbol: "mountain.2.fill", tintHex: 0x8E44AD)
    ]

    static func chapter(_ number: Int) -> Chapter {
        chapters[number - 1]
    }

    /// Notes taught up to and including `chapter` (the curriculum so far).
    static func notesTaught(through chapter: Int) -> [Int] {
        chapters.prefix(chapter).flatMap(\.newNotes)
    }

    /// Notes from earlier chapters, for review.
    static func reviewNotes(before chapter: Int) -> [Int] {
        notesTaught(through: chapter - 1)
    }

    // MARK: Stage generation

    /// Review notes closest in pitch to the chapter's new notes, at most `limit` of them.
    static func nearestReviewNotes(_ review: [Int], to new: [Int], limit: Int) -> [Int] {
        let newPitches = new.map { NoteCatalog.note($0).semitone }
        func distance(_ id: Int) -> Int {
            let pitch = NoteCatalog.note(id).semitone
            return newPitches.map { abs($0 - pitch) }.min() ?? 0
        }
        return review
            .sorted { distance($0) == distance($1) ? $0 < $1 : distance($0) < distance($1) }
            .prefix(limit)
            .map { $0 }
    }

    /// The chapter's stages, built by the rule in the game plan:
    /// two battles, an echo, then a song + battle per song, a harder echo, the boss and (chapter 6) the finale.
    static func stages(in chapter: Chapter) -> [Stage] {
        let new = chapter.newNotes
        let review = reviewNotes(before: chapter.number)
        // Seeds are filled in below, once every stage has its id.
        var kinds: [Stage.Kind] = []

        // B1: meet the notes, no timer.
        kinds.append(.battle(BattleConfig(newPool: Array(new.prefix(3)), questionCount: 6, timePerNote: nil, seed: 0)))
        // B2: first timed battle, mixing in review once there is something to review.
        if review.isEmpty {
            kinds.append(.battle(BattleConfig(newPool: Array(new.prefix(5)), questionCount: 8, timePerNote: chapter.timer, seed: 0)))
        } else {
            kinds.append(.battle(BattleConfig(newPool: new, reviewPool: review, questionCount: 8, timePerNote: chapter.timer, seed: 0)))
        }
        // E1: ear training with the new notes plus a few close review notes, keys glowing.
        kinds.append(.echo(EchoConfig(pool: new + nearestReviewNotes(review, to: new, limit: 5),
                                      roundsToClear: 3, startLength: 2, glowDuringPlayback: true, seed: 0)))
        // A song, then a battle on this chapter's notes, for each song.
        for title in chapter.songTitles {
            kinds.append(.song(songId: SongLibrary.slug(for: title)))
            kinds.append(.battle(BattleConfig(newPool: new, reviewPool: review, questionCount: 10, timePerNote: chapter.timer, seed: 0)))
        }
        // E2: longer phrases, a wider pool, no glow.
        kinds.append(.echo(EchoConfig(pool: new + nearestReviewNotes(review, to: new, limit: 8),
                                      roundsToClear: 5, startLength: 3, glowDuringPlayback: false, seed: 0)))
        kinds.append(.boss(songId: SongLibrary.slug(for: chapter.bossSongTitle)))
        if let finale = chapter.finaleSongTitle {
            kinds.append(.finale(songId: SongLibrary.slug(for: finale)))
        }

        // Give every stage its id and a seed derived from that id, so questions are stable between launches.
        return kinds.enumerated().map { offset, kind in
            let index = offset + 1
            let id = String(format: "c%d-%02d", chapter.number, index)
            return Stage(id: id, chapter: chapter.number, index: index, kind: seeded(kind, seed: SeededRandom.seed(from: id)))
        }
    }

    private static func seeded(_ kind: Stage.Kind, seed: UInt64) -> Stage.Kind {
        switch kind {
        case .battle(var config):
            config.seed = seed
            return .battle(config)
        case .echo(var config):
            config.seed = seed
            return .echo(config)
        case .song, .boss, .finale:
            return kind
        }
    }

    /// All 53 stages in play order.
    static let allStages: [Stage] = chapters.flatMap(stages(in:))

    static func stage(id: String) -> Stage? {
        allStages.first { $0.id == id }
    }

    static func stages(inChapter number: Int) -> [Stage] {
        allStages.filter { $0.chapter == number }
    }

    /// The stage before `stage` in play order (the last stage of the previous chapter for a chapter's first stage).
    static func previousStage(of stage: Stage) -> Stage? {
        guard let position = allStages.firstIndex(of: stage), position > 0 else { return nil }
        return allStages[position - 1]
    }

    // MARK: Unlocking

    /// Which chapter existing players start at, from how many classic levels they have cleared
    /// (≥ 20 / 40 / 60 / 80 / 95 unlocks chapter 2 / 3 / 4 / 5 / 6). Everyone gets chapter 1.
    static func grantedChapter(forClearedClassicLevels cleared: Int) -> Int {
        switch cleared {
        case 95...: return 6
        case 80...: return 5
        case 60...: return 4
        case 40...: return 3
        case 20...: return 2
        default: return 1
        }
    }

    /// A stage is open when the one before it has at least one star, or when it is the first stage of a
    /// chapter that existing-player migration (`grantedChapter`) has opened, or the very first stage.
    static func isUnlocked(_ stage: Stage, grantedChapter: Int, stars: (String) -> Int) -> Bool {
        if stage.chapter == 1, stage.index == 1 { return true }
        if stage.index == 1, stage.chapter <= grantedChapter { return true }
        guard let previous = previousStage(of: stage) else { return true }
        return stars(previous.id) >= 1
    }

    /// Where the player is up to: the first open stage without a star, starting from the first stage of
    /// the migrated chapter. When the whole tour is done, the last stage.
    static func currentStage(grantedChapter: Int, stars: (String) -> Int) -> Stage {
        let startChapter = max(1, min(grantedChapter, chapters.count))
        let candidates = allStages.filter { $0.chapter >= startChapter }
        return candidates.first {
            stars($0.id) == 0 && isUnlocked($0, grantedChapter: grantedChapter, stars: stars)
        } ?? allStages[allStages.count - 1]
    }
}
