//
//  Sizing.swift
//  Melodissimo
//

import UIKit

/// The running device's `LayoutScale`. Views call `Sizing.s(220)` where they used to write `220`: on iPad that
/// is `220`, on iPhone a proportionally smaller number. See `IPHONE_PLAN.md` §3.2.
enum Sizing {
    static let current = LayoutScale.make(isPhone: UIDevice.current.userInterfaceIdiom == .phone,
                                          shortSide: screenHeight)
    static var isPhone: Bool { current.isPhone }
    static func s(_ value: CGFloat) -> CGFloat { current.s(value) }
    static func f(_ value: CGFloat) -> CGFloat { current.f(value) }
    static func tap(_ value: CGFloat) -> CGFloat { current.tap(value) }
}
