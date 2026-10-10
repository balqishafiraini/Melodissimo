//
//  ViewExtension.swift
//  Melodissimo
//
//  Created by Balqis on 15/10/23.
//

import Foundation
import SwiftUI

/// The device screen width, read once. The tile layouts reference this many times
/// per render; caching it avoids repeatedly hitting `UIScreen.main` (which is also
/// deprecated) on every layout pass. The game runs in portrait, so the width is stable.
let screenWidth = UIScreen.main.bounds.width

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
