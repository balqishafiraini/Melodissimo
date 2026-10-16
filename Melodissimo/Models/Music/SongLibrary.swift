//
//  SongLibrary.swift
//  Melodissimo
//

import Foundation

/// One of the 16 songs, as a pitch sequence plus its score sheet.
struct Song: Identifiable, Hashable {
    /// Slug of the title, e.g. `"halo-halo-bandung"`. Used in persistence keys and chart file names.
    let id: String
    let title: String
    /// Asset name of the score-sheet image in `Notasi` (empty for songs that have none bundled).
    let notationImage: String
    /// The pack the song belongs to (`core` is free forever).
    var packId: String = "core"
    /// The melody as key ids, in order.
    let keyIds: [Int]
    /// National-symbol songs are played with no monster, combo effects or other comic touches.
    let isSolemn: Bool

    /// Where the score-sheet picture comes from: a downloaded file, else the bundled `Notasi` image, else none.
    func sheet(store: ContentStore = .shared) -> ArtSource? {
        if let url = store.sheetURL(songId: id) { return .file(url) }
        return notationImage.isEmpty ? nil : .asset(notationImage)
    }
}

enum SongLibrary {
    /// Titles that must stay dignified (UU 24/2009): no monster, no combo flames, no shake.
    static let solemnTitles: Set<String> = ["Indonesia Raya", "Mengheningkan Cipta", "Gugur Bunga"]

    /// Songs whose title changed; their progress is copied once to the new slug (see `ProgressStore.migrateRenamedSongs`).
    static let renamedTitles: [String: String] = ["Merah Putih": "Bendera Merah Putih"]

    /// Songs no longer in the app. Their keys stay in `UserDefaults`; "Reset progress" still clears their trophy flags.
    static let retiredTitles: Set<String> = [
        "Berkibarlah Benderaku", "Hymne Guru", "Ibu Kita Kartini", "Ibu Pertiwi", "Indonesia Pusaka",
        "Rayuan Pulau Kelapa", "Satu Nusa Satu Bangsa", "Terima Kasih Guru", "Merah Putih",
    ]

    /// Lowercases the title and replaces every run of non-alphanumeric characters with `-`.
    /// `"Halo Halo Bandung"` → `"halo-halo-bandung"`.
    static func slug(for title: String) -> String {
        var result = ""
        for character in title.lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
            } else if result.last != "-" {
                result.append("-")
            }
        }
        return result
    }

    /// The songs the app shipped with, from the old level list. Kept as the fallback, and as the source of truth for
    /// the melody of those songs (`keyIds`), so they behave exactly as before whatever a content release says.
    static let legacyAll: [Song] = LevelFeederModel.shared.songLevel.compactMap { level in
        guard let title = level.songTitle, let image = level.songNotImg else { return nil }
        return Song(id: slug(for: title),
                    title: title,
                    notationImage: image,
                    keyIds: level.answer,
                    isSolemn: solemnTitles.contains(title))
    }

    /// Where the songs come from. Tests swap it for a store with a fixture pack.
    static var contentStore: ContentStore = .shared {
        didSet { clearCache() }
    }

    private static let cacheLock = NSLock()
    private static var cachedAll: [Song]?
    private static var observesContent = false

    /// Forgets the built list; the next read builds it again. Called when a new pack goes live.
    static func clearCache() {
        cacheLock.withLock { cachedAll = nil }
    }

    /// All songs, ordered by the pack's `order`: the content store's songs, or the legacy list when the store has none.
    /// The list is cached and rebuilt after a new pack is activated.
    static var all: [Song] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if !observesContent {
            observesContent = true
            NotificationCenter.default.addObserver(forName: .contentStoreDidActivate, object: nil, queue: nil) { _ in
                clearCache()
                SongChart.clearCache()
            }
        }
        if let cachedAll { return cachedAll }
        let built = buildAll()
        cachedAll = built
        return built
    }

    private static func buildAll() -> [Song] {
        let remote = contentStore.songs
        guard !remote.isEmpty else { return legacyAll }
        let legacy = Dictionary(uniqueKeysWithValues: legacyAll.map { ($0.id, $0) })
        let songs: [Song] = remote.compactMap { entry in
            // A legacy song keeps its original melody; a new one's melody is its chart's keys.
            let keys = legacy[entry.id]?.keyIds ?? chartKeys(songId: entry.id)
            guard let keys, !keys.isEmpty else { return nil }
            return Song(id: entry.id, title: entry.canonicalTitle, notationImage: entry.bundledSheetImage ?? "",
                        packId: entry.packId, keyIds: keys,
                        isSolemn: entry.isSolemn || solemnTitles.contains(entry.canonicalTitle))
        }
        return songs.isEmpty ? legacyAll : songs
    }

    private static func chartKeys(songId: String) -> [Int]? {
        guard let url = contentStore.chartURL(songId: songId), let data = try? Data(contentsOf: url),
              let chart = try? JSONDecoder().decode(SongChart.self, from: data), chart.isValid else { return nil }
        return chart.notes.map(\.k)
    }

    static func song(id: String) -> Song? {
        all.first { $0.id == id }
    }

    static func song(title: String) -> Song? {
        all.first { $0.title == title }
    }
}
