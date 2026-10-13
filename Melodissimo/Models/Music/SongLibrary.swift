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
    /// Asset name of the score-sheet image in `Notasi`.
    let notationImage: String
    /// The melody as key ids, in order.
    let keyIds: [Int]
    /// National-symbol songs are played with no monster, combo effects or other comic touches.
    let isSolemn: Bool
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

    /// All songs, in the same order as `LevelFeederModel.songLevel`.
    static let all: [Song] = LevelFeederModel.shared.songLevel.compactMap { level in
        guard let title = level.songTitle, let image = level.songNotImg else { return nil }
        return Song(id: slug(for: title),
                    title: title,
                    notationImage: image,
                    keyIds: level.answer,
                    isSolemn: solemnTitles.contains(title))
    }

    static func song(id: String) -> Song? {
        all.first { $0.id == id }
    }

    static func song(title: String) -> Song? {
        all.first { $0.title == title }
    }
}
