//
//  SongChart.swift
//  Melodissimo
//

import Foundation

/// A note in a chart: key id, start beat and length in beats.
struct ChartNote: Codable, Hashable {
    /// Key id (1…32).
    let k: Int
    /// Start beat.
    let b: Double
    /// Duration in beats.
    let d: Double
}

/// A note placed on the song clock, in seconds.
struct TimedNote: Hashable {
    /// Position in the chart (0-based).
    let index: Int
    let keyId: Int
    let time: Double
    let duration: Double
}

/// Rhythm data for a song: a tempo and the notes with their beats. Stored as
/// `Data/Charts/chart_<slug>.json`; when no file exists, `defaultChart(for:)` builds a
/// uniform one so every song is playable from day one.
struct SongChart: Codable, Hashable {
    var id: String
    var title: String
    var bpm: Double
    var notes: [ChartNote]

    static let defaultBPM = 90.0

    /// One note per beat at 90 bpm, straight from the song's pitch sequence.
    static func defaultChart(for song: Song) -> SongChart {
        SongChart(id: song.id,
                  title: song.title,
                  bpm: defaultBPM,
                  notes: song.keyIds.enumerated().map { ChartNote(k: $1, b: Double($0), d: 1) })
    }

    /// The bundled `chart_<slug>.json` if it exists and is sound, otherwise the default chart.
    static func load(for song: Song, bundle: Bundle = .main) -> SongChart {
        guard let url = bundle.url(forResource: "chart_\(song.id)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let chart = try? JSONDecoder().decode(SongChart.self, from: data),
              chart.isValid else {
            return defaultChart(for: song)
        }
        return chart
    }

    /// A usable chart has a positive tempo and at least one note, every key is a real
    /// pianika key, durations are positive and the start beats strictly increase.
    var isValid: Bool {
        guard bpm > 0, !notes.isEmpty else { return false }
        var previousBeat = -Double.infinity
        for note in notes {
            guard (1...32).contains(note.k), note.d > 0, note.b >= 0, note.b > previousBeat else { return false }
            previousBeat = note.b
        }
        return true
    }

    /// Whether the chart plays the same key sequence as the song's melody.
    func matchesMelody(of song: Song) -> Bool {
        notes.map(\.k) == song.keyIds
    }

    /// The notes on the song clock: `time = beat × 60 / (bpm × speed)`.
    func timedNotes(speed: Double) -> [TimedNote] {
        let secondsPerBeat = 60 / (bpm * speed)
        return notes.enumerated().map { index, note in
            TimedNote(index: index,
                      keyId: note.k,
                      time: note.b * secondsPerBeat,
                      duration: note.d * secondsPerBeat)
        }
    }
}
