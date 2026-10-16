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
    /// Beats per bar, for bar lines on the score sheet. `nil` means 4.
    var beatsPerBar: Int? = nil
    /// Seconds into the backing track (at 1×) where beat 0 sounds. `nil` when the chart isn't synced to a track.
    var offset: Double? = nil
    /// Optional tempo map for recordings whose tempo moves: the track time (s, at 1×) of beat 0, 1, 2, …
    /// `beatTimes[0] == offset`. Beats past either end continue at the edge interval.
    var beatTimes: [Double]? = nil

    static let defaultBPM = 90.0

    /// One note per beat at 90 bpm, straight from the song's pitch sequence.
    static func defaultChart(for song: Song) -> SongChart {
        SongChart(id: song.id,
                  title: song.title,
                  bpm: defaultBPM,
                  notes: song.keyIds.enumerated().map { ChartNote(k: $1, b: Double($0), d: 1) })
    }

    /// Charts already read from the app bundle, by song id. A chart is decoded from disk once per launch: view bodies
    /// ask for it again and again (the score sheet), and a stage start shouldn't wait on a JSON parse. Main thread
    /// only; other bundles (tests) bypass it.
    private static var cache: [String: SongChart] = [:]

    /// Forgets the charts read so far (a new content pack went live). Main thread only.
    static func clearCache() {
        DispatchQueue.main.async { cache = [:] }
    }

    /// The chart from the content store (a downloaded pack, else the bundled baseline), then the app bundle's
    /// `chart_<slug>.json`, otherwise the default chart. Each is used only if it is sound.
    static func load(for song: Song, bundle: Bundle = .main) -> SongChart {
        guard bundle === Bundle.main else { return read(song, bundle: bundle) }
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
        if let cached = cache[song.id] { return cached }
        let chart = read(song, bundle: bundle)
        cache[song.id] = chart
        return chart
    }

    private static func read(_ song: Song, bundle: Bundle) -> SongChart {
        if bundle === Bundle.main, let url = SongLibrary.contentStore.chartURL(songId: song.id),
           let data = try? Data(contentsOf: url), let chart = try? JSONDecoder().decode(SongChart.self, from: data), chart.isValid {
            return chart
        }
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
        if let offset, offset < 0 { return false }
        if let beatsPerBar, !(1...12).contains(beatsPerBar) { return false }
        if let map = beatTimes {
            guard map.count >= 2, let offset, abs(map[0] - offset) < 0.001 else { return false }
            for (a, b) in zip(map, map.dropFirst()) where b <= a { return false }
        }
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

    /// Seconds after beat 0 at 1× speed.
    func seconds(atBeat beat: Double) -> Double {
        guard let map = beatTimes, map.count >= 2 else { return beat * 60 / bpm }
        let i = min(max(Int(beat.rounded(.down)), 0), map.count - 2)
        return map[i] + (beat - Double(i)) * (map[i + 1] - map[i]) - map[0]
    }

    /// The backing-track position that goes with a song-clock time (song time 0 = beat 0).
    func backingTime(songTime: Double, speed: Double) -> Double {
        (offset ?? 0) + songTime * speed
    }

    /// The notes on the song clock: `time = seconds(atBeat: b) / speed`.
    func timedNotes(speed: Double) -> [TimedNote] {
        notes.enumerated().map { index, note in
            let start = seconds(atBeat: note.b)
            return TimedNote(index: index,
                             keyId: note.k,
                             time: start / speed,
                             duration: (seconds(atBeat: note.b + note.d) - start) / speed)
        }
    }
}
