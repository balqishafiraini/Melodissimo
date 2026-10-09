//
//  Color+Hex.swift
//  Melodissimo
//

import SwiftUI

extension Color {
    /// 0xRRGGBB, as stored in `Chapter.tintHex` (models don't import SwiftUI, so views convert it).
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
