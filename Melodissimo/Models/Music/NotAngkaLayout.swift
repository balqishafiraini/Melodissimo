//
//  NotAngkaLayout.swift
//  Melodissimo
//

import Foundation

/// What one slot of a beat shows on the score sheet.
enum NotAngkaSymbol: Hashable {
    /// A note starts here.
    case note(keyId: Int)
    /// The previous note is still sounding (drawn as a dot).
    case hold
    case rest
}

/// One beat of a bar, split into 1, 2, 3, 4, 6 or 8 equal slots.
struct NotAngkaBeat: Hashable {
    let slots: [NotAngkaSymbol]
}

struct NotAngkaBar: Hashable {
    /// The pickup bar is 0, the first full bar 1.
    let number: Int
    let beats: [NotAngkaBeat]
}

/// Turns a chart into bars of beats for the score sheet, so the sheet always matches what the stage plays.
/// Pure and testable: the sheet view only draws what this returns.
enum NotAngkaLayout {
    /// Slot counts a beat can be split into, smallest first.
    static let slotCounts = [1, 2, 3, 4, 6, 8]
    private static let tolerance = 0.01

    static func bars(for chart: SongChart) -> [NotAngkaBar] {
        let notes = chart.notes.sorted { ($0.b, $0.k) < ($1.b, $1.k) }
        guard let first = notes.first else { return [] }
        let beatsPerBar = max(chart.beatsPerBar ?? 4, 1)
        let end = notes.map { $0.b + $0.d }.max() ?? first.b
        let beatCount = max(Int((end - tolerance).rounded(.up)), 1)

        var beats: [NotAngkaBeat] = []
        for index in 0..<beatCount {
            beats.append(beat(at: Double(index), notes: notes))
        }

        var bars: [NotAngkaBar] = []
        var offset = 0
        // The first note decides whether the first bar is a pickup bar.
        let hasPickup = first.b >= 1 - tolerance
        while offset < beats.count {
            var chunk = Array(beats[offset..<min(offset + beatsPerBar, beats.count)])
            if offset == 0 {
                // A pickup shows only its notes, not the rests before them.
                while chunk.count > 1, chunk[0].slots.allSatisfy({ $0 == .rest }) { chunk.removeFirst() }
            }
            let number = hasPickup ? bars.count : bars.count + 1
            bars.append(NotAngkaBar(number: number, beats: chunk))
            offset += beatsPerBar
        }
        return bars
    }

    /// The smallest slot count that puts every note start/end inside the beat on a slot.
    private static func beat(at start: Double, notes: [ChartNote]) -> NotAngkaBeat {
        let inner = notes.flatMap { [$0.b, $0.b + $0.d] }.filter { $0 > start + tolerance && $0 < start + 1 - tolerance }
        func onGrid(_ offset: Double, _ count: Int) -> Bool {
            abs(offset * Double(count) - (offset * Double(count)).rounded()) < tolerance * Double(count)
        }
        let count = slotCounts.first { count in inner.allSatisfy { onGrid($0 - start, count) } } ?? 8
        let slots: [NotAngkaSymbol] = (0..<count).map { slot in
            let time = start + Double(slot) / Double(count)
            if let note = notes.first(where: { abs($0.b - time) < tolerance }) {
                return .note(keyId: note.k)
            }
            if notes.contains(where: { $0.b < time - tolerance && time + 1e-9 < $0.b + $0.d - tolerance }) {
                return .hold
            }
            return .rest
        }
        return NotAngkaBeat(slots: slots)
    }

    // MARK: Label parts

    /// How a key's label is drawn: its digit, octave dots and sharp. `4˙#` → digit 4, one dot above, sharp.
    struct Glyph: Equatable {
        let digit: String
        let dotsAbove: Int
        let dotsBelow: Int
        let isSharp: Bool
    }

    static func glyph(forKeyId keyId: Int) -> Glyph {
        let label = NoteCatalog.note(keyId).label
        return Glyph(digit: String(label.prefix(1)),
                     dotsAbove: label.filter { $0 == "˙" }.count,
                     dotsBelow: label.filter { $0 == "." }.count,
                     isSharp: label.contains("#"))
    }
}
