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
    /// How many cities (kota) the island has. Sets its share of the tour's 100 stages.
    let cityCount: Int
    /// Key ids introduced here, in the order they are taught.
    let newNotes: [Int]
    let songTitles: [String]
    let bossSongTitle: String
    /// The last chapter ends with the national anthem as a solemn ceremony.
    let finaleSongTitle: String?
    /// Seconds per note in this chapter's battles; `nil` means no timer.
    let timer: Double?
    /// SF Symbol shown on the map.
    let symbol: String
    /// 0xRRGGBB, converted to a `Color` by the views (models don't import SwiftUI).
    let tintHex: UInt32
    // The island's pictures are `map_island_<number>` and `fals_boss_<number>`.

    var id: Int { number }
}

/// A stage on the map. Stages are generated from the chapters, never hand-written.
struct Stage: Identifiable, Hashable {
    enum Kind: Hashable {
        case battle(BattleConfig)
        case echo(EchoConfig)
        case quiz(QuizConfig)
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
        Chapter(number: 1, name: "Sumatra", cityCount: 34,
                newNotes: [5, 6, 7, 8, 9, 10, 11, 12, 2, 4],
                songTitles: ["Bendera Merah Putih"], bossSongTitle: "Indonesia Tetap Merdeka", finaleSongTitle: nil,
                timer: nil, symbol: "leaf.fill", tintHex: 0x27AE60),
        Chapter(number: 2, name: "Jawa", cityCount: 34,
                newNotes: [3, 1],
                songTitles: ["Halo Halo Bandung", "Bhinneka Tunggal Ika"],
                bossSongTitle: "Garuda Pancasila", finaleSongTitle: nil,
                timer: 6, symbol: "building.columns.fill", tintHex: 0xC0392B),
        Chapter(number: 3, name: "Kalimantan", cityCount: 9,
                newNotes: [13, 14],
                songTitles: ["Bagimu Negeri"], bossSongTitle: "Hari Merdeka", finaleSongTitle: nil,
                timer: 5, symbol: "tree.fill", tintHex: 0x117A65),
        Chapter(number: 4, name: "Sulawesi", cityCount: 11,
                newNotes: [15, 16, 17],
                songTitles: ["Gugur Bunga"], bossSongTitle: "Maju Tak Gentar", finaleSongTitle: nil,
                timer: 4.5, symbol: "sailboat.fill", tintHex: 0x2980B9),
        Chapter(number: 5, name: "Bali", cityCount: 1,
                newNotes: [25, 23],
                songTitles: ["Mengheningkan Cipta"], bossSongTitle: "Api Kemerdekaan", finaleSongTitle: nil,
                timer: 4, symbol: "sun.max.fill", tintHex: 0xE67E22),
        Chapter(number: 6, name: "Nusa Tenggara", cityCount: 3,
                newNotes: [26, 24, 27],
                songTitles: [], bossSongTitle: "Tanah Airku", finaleSongTitle: nil,
                timer: 4, symbol: "beach.umbrella.fill", tintHex: 0xD35400),
        Chapter(number: 7, name: "Maluku", cityCount: 4,
                newNotes: [18, 19, 20, 21, 22],
                songTitles: [], bossSongTitle: "Mars Harapan Bangsa", finaleSongTitle: nil,
                timer: 3.5, symbol: "fish.fill", tintHex: 0x16A085),
        Chapter(number: 8, name: "Papua", cityCount: 2,
                newNotes: [28, 29, 30, 31, 32],
                songTitles: ["Dari Sabang Sampai Merauke"], bossSongTitle: "Bangun Pemudi Pemuda", finaleSongTitle: "Indonesia Raya",
                timer: 3.5, symbol: "mountain.2.fill", tintHex: 0x8E44AD)
    ]

    /// Stages in the whole tour, shared out between the islands by `stageCounts`.
    static let totalStages = 100

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

    /// The fewest stages a chapter can have: the opening battle, battle, echo; a song and battle per song;
    /// the closing echo and boss; and the finale if it has one.
    static func minimumStages(in chapter: Chapter) -> Int {
        3 + 2 * chapter.songTitles.count + 2 + (chapter.finaleSongTitle == nil ? 0 : 1)
    }

    /// Every island gets this many stages before the rest is shared out by city count, so small islands aren't tiny.
    static let baseStages = 10

    /// How many stages each chapter gets: `baseStages` each, plus the rest of `total` shared out in proportion to
    /// the islands' city counts, except that no island goes below its `minimumStages` (those are fixed first and
    /// the rest re-shared among the others). Rounding uses largest remainders, so the counts always add up to `total`.
    static func stageCounts(for chapters: [Chapter], total: Int, base: Int = baseStages) -> [Int] {
        var fixed: [Int: Int] = [:]
        while true {
            let open = chapters.indices.filter { fixed[$0] == nil }
            let left = total - fixed.values.reduce(0, +)
            let cities = open.reduce(0) { $0 + chapters[$1].cityCount }
            let spare = Double(left - base * open.count)
            let shares = Dictionary(uniqueKeysWithValues: open.map {
                ($0, Double(base) + (cities == 0 ? 0 : spare * Double(chapters[$0].cityCount) / Double(cities)))
            })
            let short = open.filter { shares[$0]! < Double(minimumStages(in: chapters[$0])) }
            if short.isEmpty {
                var counts = shares.mapValues { Int($0.rounded(.down)) }
                let remaining = left - counts.values.reduce(0, +)
                let byRemainder = open.sorted {
                    let a = shares[$0]! - Double(counts[$0]!), b = shares[$1]! - Double(counts[$1]!)
                    return a == b ? $0 < $1 : a > b
                }
                for index in byRemainder.prefix(remaining) { counts[index]! += 1 }
                return chapters.indices.map { fixed[$0] ?? counts[$0]! }
            }
            for index in short { fixed[index] = minimumStages(in: chapters[index]) }
        }
    }

    static let stageCounts: [Int] = stageCounts(for: chapters, total: totalStages)

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
    /// two battles, an echo, then a song + battle per song, a harder echo, the boss and (last chapter) the finale.
    /// Bigger islands get extra practice stages (battles, echoes and listening quizzes) spread before each song and
    /// before the closing echo, so the chapter has exactly `count` stages (never fewer than `minimumStages`).
    static func stages(in chapter: Chapter, count: Int) -> [Stage] {
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
        // Extra practice, shared out as evenly as possible over the gaps before each song and before E2.
        let extras = max(0, count - minimumStages(in: chapter))
        let gaps = chapter.songTitles.count + 1
        var extrasPlaced = 0
        func appendExtras(gap: Int) {
            let upTo = extras * (gap + 1) / gaps
            while extrasPlaced < upTo {
                kinds.append(practiceStage(extrasPlaced, of: extras, chapter: chapter, review: review))
                extrasPlaced += 1
            }
        }
        // A song, then a battle on this chapter's notes, for each song.
        for (gap, title) in chapter.songTitles.enumerated() {
            appendExtras(gap: gap)
            kinds.append(.song(songId: SongLibrary.slug(for: title)))
            kinds.append(.battle(BattleConfig(newPool: new, reviewPool: review, questionCount: 10, timePerNote: chapter.timer, seed: 0)))
        }
        appendExtras(gap: gaps - 1)
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

    /// Extra practice stage number `index` of `total`: battles and echoes taking turns, with every third one a
    /// listening quiz (and the last one, on islands with fewer than three, so every island has a quiz). They get a
    /// little harder as the island goes on. With nothing to review yet (the first island) the battles widen the
    /// new-note pool step by step.
    private static func practiceStage(_ index: Int, of total: Int, chapter: Chapter, review: [Int]) -> Stage.Kind {
        if index % quizEvery == quizEvery - 1 {
            return quizStage(index / quizEvery, chapter: chapter)
        }
        if total < quizEvery, index == total - 1 {
            return quizStage(0, chapter: chapter)
        }
        let new = chapter.newNotes
        let progress = total > 1 ? Double(index) / Double(total - 1) : 1
        if index % 2 == 0 {
            let questions = 8 + Int((progress * 4).rounded())
            if review.isEmpty {
                let size = min(new.count, 5 + Int((progress * Double(max(0, new.count - 5))).rounded()))
                return .battle(BattleConfig(newPool: Array(new.prefix(size)), questionCount: questions, timePerNote: chapter.timer, seed: 0))
            }
            return .battle(BattleConfig(newPool: new, reviewPool: review, questionCount: questions, timePerNote: chapter.timer, seed: 0))
        }
        let late = progress >= 0.5
        return .echo(EchoConfig(pool: new + nearestReviewNotes(review, to: new, limit: late ? 8 : 5),
                                roundsToClear: late ? 4 : 3, startLength: late ? 3 : 2, glowDuringPlayback: !late, seed: 0))
    }

    /// Every this-many extra practice stages, one is a quiz.
    static let quizEvery = 3

    /// Questions per tour quiz (Free Play's runs have ten).
    static let quizQuestions = 8

    /// Songs met on earlier islands (their songs, boss and finale): every one has been played by then.
    static func songsHeard(before chapter: Int) -> [String] {
        chapters.prefix(chapter - 1).flatMap { $0.songTitles + [$0.bossSongTitle] + ($0.finaleSongTitle.map { [$0] } ?? []) }
    }

    /// The quizzes an island can hold: Guess the Song once enough songs are known for a full set of choices,
    /// Spot Fals once there is a known song he may touch (never a solemn one), and Higher or lower always.
    static func quizVariants(in chapter: Chapter) -> [QuizVariant] {
        let heard = songsHeard(before: chapter.number)
        var variants: [QuizVariant] = []
        if heard.count >= QuizQuestionGenerator.titleChoices { variants.append(.guessSong) }
        if heard.contains(where: { !SongLibrary.solemnTitles.contains($0) }) { variants.append(.spotFals) }
        variants.append(.higherLower)
        return variants
    }

    /// The island's quiz number `number`, taking turns through `quizVariants`; each island starts on a different one.
    private static func quizStage(_ number: Int, chapter: Chapter) -> Stage.Kind {
        let variants = quizVariants(in: chapter)
        let variant = variants[(chapter.number + number) % variants.count]
        return .quiz(QuizConfig(variant: variant, questionCount: quizQuestions, seed: 0,
                                songTitles: variant == .higherLower ? nil : songsHeard(before: chapter.number)))
    }

    private static func seeded(_ kind: Stage.Kind, seed: UInt64) -> Stage.Kind {
        switch kind {
        case .battle(var config):
            config.seed = seed
            return .battle(config)
        case .echo(var config):
            config.seed = seed
            return .echo(config)
        case .quiz(var config):
            config.seed = seed
            return .quiz(config)
        case .song, .boss, .finale:
            return kind
        }
    }

    /// All 100 stages in play order.
    static let allStages: [Stage] = zip(chapters, stageCounts).flatMap { stages(in: $0, count: $1) }

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
    /// (≥ 20 / 40 / 60 / 80 / 95 unlocks Jawa / Kalimantan / Sulawesi / Bali / Maluku). Everyone gets chapter 1.
    static func grantedChapter(forClearedClassicLevels cleared: Int) -> Int {
        switch cleared {
        case 95...: return 7
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
