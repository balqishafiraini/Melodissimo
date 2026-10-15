//
//  LayoutScale.swift
//  Melodissimo
//

import CoreGraphics

/// Sizing factors for one device class. The views were drawn for an iPad (landscape height ≈ 820 pt);
/// on iPhone every fixed size is scaled down from that, and on iPad every helper returns its input untouched.
struct LayoutScale: Equatable {
    let isPhone: Bool
    /// Multiplies fixed frame sizes, paddings, spacings, corner radii and offsets.
    let size: CGFloat
    /// Multiplies custom font point sizes.
    let font: CGFloat

    static let pad = LayoutScale(isPhone: false, size: 1, font: 1)

    /// `shortSide` is the screen's shorter edge in points (landscape height).
    static func make(isPhone: Bool, shortSide: CGFloat) -> LayoutScale {
        guard isPhone else { return .pad }
        let size = min(max(shortSide / 820, 0.44), 0.56)
        return LayoutScale(isPhone: true, size: size, font: 0.65)
    }

    /// A fixed iPad size, scaled for this device.
    func s(_ value: CGFloat) -> CGFloat { isPhone ? (value * size).rounded() : value }
    /// A custom font size, scaled for this device; never below 13 pt on iPhone.
    func f(_ value: CGFloat) -> CGFloat { isPhone ? max(13, (value * font).rounded()) : value }
    /// A tappable control's side, scaled but never below Apple's 44 pt minimum on iPhone.
    func tap(_ value: CGFloat) -> CGFloat { isPhone ? max(44, s(value)) : value }
}
