//
//  MapLayout.swift
//  Melodissimo
//

import Foundation

/// Where the stage nodes sit on a chapter's island panel. Positions are fractions of the panel
/// (0...1), so the layout scales to any iPad. Up to `maxPerRow` nodes zig-zag from left to right; a bigger
/// island winds back and forth over several rows. Either way the top of the panel stays free for the island's
/// name and star total.
enum MapLayout {
    static let leftMargin = 0.08
    static let rightMargin = 0.92
    /// Heights of the lower and upper rows of the zig-zag.
    static let lowerRow = 0.70
    static let upperRow = 0.50
    /// The most nodes a single zig-zag (or one row of a winding path) holds.
    static let maxPerRow = 12
    /// Where the first and last rows of a winding path sit, and how far its nodes bob up and down.
    static let firstRow = 0.52
    static let lastRow = 0.84
    static let bob = 0.03

    /// One position per node: spread evenly across the width, alternating between the two rows. More than
    /// `maxPerRow` nodes run in rows instead, left to right then right to left.
    static func nodeFractions(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        if count == 1 { return [CGPoint(x: 0.5, y: lowerRow)] }
        if count > maxPerRow { return windingFractions(count: count) }
        return (0..<count).map { index in
            let progress = Double(index) / Double(count - 1)
            return CGPoint(x: leftMargin + (rightMargin - leftMargin) * progress,
                           y: index % 2 == 0 ? lowerRow : upperRow)
        }
    }

    private static func windingFractions(count: Int) -> [CGPoint] {
        let rows = (count + maxPerRow - 1) / maxPerRow
        let perRow = (count + rows - 1) / rows
        let rowStep = (lastRow - firstRow) / Double(rows - 1)
        return (0..<count).map { index in
            let row = index / perRow
            let column = index % perRow
            let slot = row % 2 == 0 ? column : perRow - 1 - column
            let x = leftMargin + (rightMargin - leftMargin) * Double(slot) / Double(perRow - 1)
            let y = firstRow + rowStep * Double(row) + (column % 2 == 0 ? bob : -bob)
            return CGPoint(x: x, y: y)
        }
    }

    /// Scales fractional positions to a panel of the given size.
    static func points(count: Int, in size: CGSize) -> [CGPoint] {
        nodeFractions(count: count).map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }
}
