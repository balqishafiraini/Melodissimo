//
//  ChartQuantizer.swift
//  Melodissimo
//

import Foundation

/// A key press made while recording a chart: when it happened (host time) and which key.
struct RecordedPress: Hashable {
    let time: Double
    let keyId: Int
}

/// Turns a live recording into chart notes, and chart files into JSON. Used by the DEBUG
/// Chart Recorder; pure so it can be tested.
enum ChartQuantizer {

    /// The note grid choices: half a beat or a quarter of a beat.
    static let grids: [Double] = [0.5, 0.25]

    /// Snaps each press to the grid, relative to the first press:
    /// `b_i = round((t_i − t_0) / secondsPerBeat / grid) × grid`.
    /// Colliding beats are pushed on by one grid step so they strictly increase,
    /// each duration runs to the next note's beat, and the last note lasts 2 beats.
    static func quantize(_ presses: [RecordedPress], bpm: Double, grid: Double) -> [ChartNote] {
        guard let first = presses.first, bpm > 0, grid > 0 else { return [] }
        let secondsPerBeat = 60 / bpm

        var beats: [Double] = []
        for press in presses {
            var beat = ((press.time - first.time) / secondsPerBeat / grid).rounded() * grid
            if let previous = beats.last, beat <= previous {
                beat = previous + grid
            }
            beats.append(beat)
        }

        return presses.enumerated().map { index, press in
            let duration = index + 1 < beats.count ? beats[index + 1] - beats[index] : 2
            return ChartNote(k: press.keyId, b: beats[index], d: duration)
        }
    }

    /// A chart ready to save: the song's id and title with the recorded tempo and notes.
    static func chart(for song: Song, bpm: Double, notes: [ChartNote]) -> SongChart {
        SongChart(id: song.id, title: song.title, bpm: bpm, notes: notes)
    }

    /// Pretty-printed JSON with sorted keys, so recordings diff cleanly.
    static func json(for chart: SongChart) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(chart), as: UTF8.self)
    }

    /// The file a song's chart is saved as: `chart_<slug>.json`.
    static func fileName(for song: Song) -> String {
        "chart_\(song.id).json"
    }

    /// Writes the chart as `chart_<slug>.json` inside `directory` and returns the file's URL.
    @discardableResult
    static func write(_ chart: SongChart, for song: Song, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(fileName(for: song))
        try json(for: chart).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
