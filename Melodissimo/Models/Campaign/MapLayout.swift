//
//  MapLayout.swift
//  Melodissimo
//

import Foundation

/// Where the stage nodes sit on a chapter's island panel. Positions are fractions of the panel
/// (0...1), so the layout scales to any iPad. The nodes zig-zag from left to right, leaving the
/// top of the panel free for the island's name and star total.
enum MapLayout {
    static let leftMargin = 0.08
    static let rightMargin = 0.92
    /// Heights of the lower and upper rows of the zig-zag.
    static let lowerRow = 0.70
    static let upperRow = 0.50

    /// One position per node: spread evenly across the width, alternating between the two rows.
    static func nodeFractions(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        if count == 1 { return [CGPoint(x: 0.5, y: lowerRow)] }
        return (0..<count).map { index in
            let progress = Double(index) / Double(count - 1)
            return CGPoint(x: leftMargin + (rightMargin - leftMargin) * progress,
                           y: index % 2 == 0 ? lowerRow : upperRow)
        }
    }

    /// Scales fractional positions to a panel of the given size.
    static func points(count: Int, in size: CGSize) -> [CGPoint] {
        nodeFractions(count: count).map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }
}
