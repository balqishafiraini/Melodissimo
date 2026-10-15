//
//  Note.swift
//  Melodissimo
//

import Foundation

/// One of the 32 pianika keys (F3…C6, written in *not angka*).
struct Note: Identifiable, Hashable {
    /// 1…32. Persisted (e.g. `LevelModel.answer`), so it must never be renumbered.
    let id: Int
    /// *Not angka* label, e.g. `"5."`, `"1˙"`, `"4#"`.
    let label: String
    /// Resource name of the `.m4a` sample.
    let sound: String
    /// Pitch order, 0 = F3. MIDI note number = `53 + semitone`.
    let semitone: Int

    var isBlack: Bool { id >= 20 }
}

/// The single source of truth for the 32 keys: ids, labels, samples and pitch order.
enum NoteCatalog {
    static let all: [Note] = [
        Note(id: 1, label: "4.", sound: "f1", semitone: 0),
        Note(id: 2, label: "5.", sound: "g1", semitone: 2),
        Note(id: 3, label: "6.", sound: "a1", semitone: 4),
        Note(id: 4, label: "7.", sound: "b1", semitone: 6),
        Note(id: 5, label: "1", sound: "c2", semitone: 7),
        Note(id: 6, label: "2", sound: "d2", semitone: 9),
        Note(id: 7, label: "3", sound: "e2", semitone: 11),
        Note(id: 8, label: "4", sound: "f2", semitone: 12),
        Note(id: 9, label: "5", sound: "g2", semitone: 14),
        Note(id: 10, label: "6", sound: "a2", semitone: 16),
        Note(id: 11, label: "7", sound: "b2", semitone: 18),
        Note(id: 12, label: "1˙", sound: "c3", semitone: 19),
        Note(id: 13, label: "2˙", sound: "d3", semitone: 21),
        Note(id: 14, label: "3˙", sound: "e3", semitone: 23),
        Note(id: 15, label: "4˙", sound: "f3", semitone: 24),
        Note(id: 16, label: "5˙", sound: "g3", semitone: 26),
        Note(id: 17, label: "6˙", sound: "a3", semitone: 28),
        Note(id: 18, label: "7˙", sound: "b3", semitone: 30),
        Note(id: 19, label: "1˙˙", sound: "c4", semitone: 31),
        Note(id: 20, label: "4.#", sound: "f1s", semitone: 1),
        Note(id: 21, label: "5.#", sound: "g1s", semitone: 3),
        Note(id: 22, label: "6.#", sound: "a1s", semitone: 5),
        Note(id: 23, label: "1#", sound: "c2s", semitone: 8),
        Note(id: 24, label: "2#", sound: "d2s", semitone: 10),
        Note(id: 25, label: "4#", sound: "f2s", semitone: 13),
        Note(id: 26, label: "5#", sound: "g2s", semitone: 15),
        Note(id: 27, label: "6#", sound: "a2s", semitone: 17),
        Note(id: 28, label: "1˙#", sound: "c3s", semitone: 20),
        Note(id: 29, label: "2˙#", sound: "d3s", semitone: 22),
        Note(id: 30, label: "4˙#", sound: "f3s", semitone: 25),
        Note(id: 31, label: "5˙#", sound: "g3s", semitone: 27),
        Note(id: 32, label: "6˙#", sound: "a3s", semitone: 29)
    ]

    static let whiteKeyIDs = Array(1...19)
    static let blackKeyIDs = Array(20...32)

    private static let notesByID: [Int: Note] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    private static let idsByLabel: [String: Int] = Dictionary(uniqueKeysWithValues: all.map { ($0.label, $0.id) })

    /// The note for a key id. Precondition: `id` is in 1…32.
    static func note(_ id: Int) -> Note {
        guard let note = notesByID[id] else {
            preconditionFailure("NoteCatalog: unknown key id \(id)")
        }
        return note
    }

    /// The key id for a *not angka* label, or `nil` if the label isn't a pianika key.
    static func id(forLabel label: String) -> Int? {
        idsByLabel[label]
    }
}
