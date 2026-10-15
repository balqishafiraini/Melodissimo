//
//  Sizing.swift
//  Melodissimo
//

import SwiftUI
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

extension Sizing {
    /// The window's safe-area insets, for views that draw over the whole screen and so can't ask their own
    /// geometry (it reports 0 inside `.ignoresSafeArea()`). Zero on iPad, where the landscape sides have no inset.
    static var windowInsets: EdgeInsets {
        guard isPhone,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.keyWindow
        else { return EdgeInsets() }
        let insets = window.safeAreaInsets
        return EdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)
    }

    /// The shortest phones (iPhone SE, 375 pt tall) get slimmer bars so the play screens keep their room.
    static var isCompactHeight: Bool { isPhone && screenHeight < 380 }
}

extension Sizing {
    /// The top bar (Menu / Back, title, "?") on every iPhone screen sits this far below the safe area's top edge,
    /// this far in from its sides, and its buttons are this tall. iPad keeps each screen's own numbers.
    static let topBarInset: CGFloat = 12
    static let topBarSide: CGFloat = 16
    static var topBarButton: CGFloat { tap(56) }
}

extension View {
    /// The padding of a screen whose first row is the top bar. iPad: `.padding(.all, ipad)` exactly as before
    /// (`nil` is the system default). iPhone: `topBarInset` above, `topBarSide` beside, a little below, so the
    /// row lands at the same place on every screen.
    @ViewBuilder
    func topBarScreenPadding(ipad: CGFloat?) -> some View {
        if Sizing.isPhone {
            padding(.top, Sizing.topBarInset).padding(.horizontal, Sizing.topBarSide).padding(.bottom, 6)
        } else {
            padding(.all, ipad)
        }
    }

    /// The same placement for a top bar that carries its own padding. iPhone only; iPad is left as drawn.
    @ViewBuilder
    func phoneTopBarRow() -> some View {
        if Sizing.isPhone {
            padding(.top, Sizing.topBarInset).padding(.horizontal, Sizing.topBarSide)
        } else {
            self
        }
    }

    /// The old screens' "fill the screen" frame. iPad: as wide as it can be and exactly the screen's height (what
    /// `UIScreen.main.bounds.size.height` gave). iPhone: whatever the safe area leaves.
    func fillsScreenHeight(alignment: Alignment = .topLeading) -> some View {
        frame(maxWidth: .infinity, maxHeight: Sizing.isPhone ? .infinity : screenHeight, alignment: alignment)
    }

    /// A button label's frame. On iPad exactly `width × height`, as drawn. On iPhone it is at least the scaled size
    /// (never under 44 pt) and grows to fit its one line of text, so a long label such as an Indonesian one never clips.
    func buttonFrame(width: CGFloat, height: CGFloat) -> some View {
        modifier(ButtonFrame(width: width, height: height))
    }
}

private struct ButtonFrame: ViewModifier {
    let width: CGFloat
    let height: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if Sizing.isPhone {
            content
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 14)
                .frame(minWidth: Sizing.tap(width), minHeight: Sizing.tap(height))
        } else {
            content.frame(width: width, height: height)
        }
    }
}
