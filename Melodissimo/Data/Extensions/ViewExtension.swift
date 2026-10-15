//
//  ViewExtension.swift
//  Melodissimo
//
//  Created by Balqis on 15/10/23.
//

import Foundation
import SwiftUI

/// The screen's long edge, read once. The app is landscape-only, so this is the landscape width on every device,
/// even if it is read before the window has rotated. The tile layouts reference it many times per render;
/// caching it avoids repeatedly hitting `UIScreen.main` (which is also deprecated) on every layout pass.
let screenWidth = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
/// The screen's short edge: the landscape height.
let screenHeight = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)

struct CornerRadiusShape: Shape {
    var radius = CGFloat.infinity
    var corners = UIRectCorner.allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct CornerRadiusStyle: ViewModifier {
    var radius: CGFloat
    var corners: UIRectCorner

    func body(content: Content) -> some View {
        content
            .clipShape(CornerRadiusShape(radius: radius, corners: corners))
    }
}

extension View {
    func cornerRadius(radius: CGFloat, corners: UIRectCorner) -> some View {
        ModifiedContent(content: self, modifier: CornerRadiusStyle(radius: radius, corners: corners))
    }
}
