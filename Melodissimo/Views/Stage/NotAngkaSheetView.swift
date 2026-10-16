//
//  NotAngkaSheetView.swift
//  Melodissimo
//

import SwiftUI

/// The song's score sheet in *not angka*, drawn from the chart, so it always matches what the stage plays
/// (and the backing track). Scrolls vertically; four bars to a row.
struct NotAngkaSheetView: View {
    let chart: SongChart

    /// Four bars to a row on iPad; two on iPhone, where a row of four would leave each note a few points to stand in.
    private let barsPerRow = Sizing.isPhone ? 2 : 4
    private var bars: [NotAngkaBar] { NotAngkaLayout.bars(for: chart) }
    private var rows: [[NotAngkaBar]] {
        stride(from: 0, to: bars.count, by: barsPerRow).map { Array(bars[$0..<min($0 + barsPerRow, bars.count)]) }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(headerText)
                .font(.custom("BalooDa-Regular", size: Sizing.f(22)))
                .foregroundColor(Color.darkGreen.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 18) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                        HStack(spacing: 0) {
                            barline
                            ForEach(row, id: \.number) { bar in
                                BarView(bar: bar)
                                    .frame(maxWidth: .infinity)
                                barline
                            }
                            if rowIndex == rows.count - 1 { barline }
                            if row.count < barsPerRow {
                                // Keep the last row's bars the same width as the others.
                                ForEach(0..<(barsPerRow - row.count), id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var barline: some View {
        Rectangle().fill(Color.darkGreen.opacity(0.7)).frame(width: 2, height: Sizing.isPhone ? 46 : 52)
    }

    /// "do = C · 4/4 · ♩ = 112"
    private var headerText: String {
        let meter = chart.beatsPerBar ?? 4
        return "do = C · \(meter)/4 · ♩ = \(Int(chart.bpm.rounded()))"
    }
}

private struct BarView: View {
    let bar: NotAngkaBar

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(bar.beats.enumerated()), id: \.offset) { _, beat in
                BeatView(beat: beat)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// One beat: its slots side by side, with the beam lines of the rhythm under them.
private struct BeatView: View {
    let beat: NotAngkaBeat
    /// The note names the sheet is written in; follows the setting.
    @ObservedObject private var progress = ProgressStore.shared

    private var fontSize: CGFloat {
        switch beat.slots.count {
        case 1: return Sizing.isPhone ? 24 : 32
        case 2: return Sizing.isPhone ? 20 : 26
        case 3: return Sizing.isPhone ? 17 : 22
        default: return Sizing.isPhone ? 14 : 18
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 0) {
                ForEach(Array(beat.slots.enumerated()), id: \.offset) { _, slot in
                    SlotView(style: progress.noteLabelStyle, symbol: slot, fontSize: fontSize)
                        .frame(maxWidth: .infinity)
                }
            }
            beams
        }
    }

    /// One line for two slots, two for four or eight, one plus a small 3 for three or six.
    @ViewBuilder
    private var beams: some View {
        let count = beat.slots.count
        VStack(spacing: 2) {
            switch count {
            case 2:
                line
            case 4, 8:
                line
                line
            case 3, 6:
                HStack(spacing: 2) {
                    line
                    Text("3").font(.system(size: 10, weight: .bold)).foregroundColor(Color.darkGreen)
                }
            default:
                Color.clear.frame(height: 2)
            }
        }
        .frame(height: 8, alignment: .top)
    }

    private var line: some View {
        Rectangle().fill(Color.darkGreen).frame(height: 1.5)
    }
}

private struct SlotView: View {
    let style: NoteLabelStyle
    let symbol: NotAngkaSymbol
    let fontSize: CGFloat

    var body: some View {
        switch symbol {
        case .note(let keyId):
            NoteGlyphView(glyph: NotAngkaLayout.glyph(forKeyId: keyId, style: style),
                          fontSize: style == .notAngka ? fontSize : fontSize * 0.7)
        case .hold:
            glyphSpace { Text("·") }
        case .rest:
            glyphSpace { Text("0") }
        }
    }

    private func glyphSpace<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 1) {
            Color.clear.frame(height: 11)
            content()
                .font(.custom("BalooDa-Regular", size: fontSize))
                .foregroundColor(Color.darkGreen)
            Color.clear.frame(height: 6)
        }
    }
}

/// A digit with its octave dots (above for high, below for low) and a small sharp sign.
private struct NoteGlyphView: View {
    let glyph: NotAngkaLayout.Glyph
    let fontSize: CGFloat

    var body: some View {
        VStack(spacing: 1) {
            // Room for two dots above, so every digit sits on the same baseline.
            VStack(spacing: 1) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(index < glyph.dotsAbove ? Color.darkGreen : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 11)
            Text(glyph.digit)
                .font(.custom("BalooDa-Regular", size: fontSize))
                .foregroundColor(Color.darkGreen)
                .overlay(alignment: .topTrailing) {
                    if glyph.isSharp {
                        Text("#")
                            .font(.system(size: fontSize * 0.45, weight: .bold))
                            .foregroundColor(Color.darkGreen)
                            .offset(x: fontSize * 0.3, y: -2)
                    }
                }
            Circle()
                .fill(glyph.dotsBelow > 0 ? Color.darkGreen : Color.clear)
                .frame(width: 4, height: 4)
                .padding(.vertical, 1)
        }
    }
}
