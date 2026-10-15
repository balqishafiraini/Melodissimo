//
//  ButtonExtension.swift
//  Melodissimo
//
//  Created by Balqis on 09/12/23.
//

import Foundation
import SwiftUI

//style white tiles
struct WhiteTilesStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: screenWidth*0.048, height: Sizing.s(350), alignment: .bottom)
            .background(isPressed ? .gray : .white)
            .foregroundColor(!isPressed ? .black : .white)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}

//style black tiles
struct BlackTilesStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: screenWidth*0.042, height: Sizing.s(220), alignment: .bottom)
            .background(isPressed ? .gray : .black)
            .foregroundColor(!isPressed ? .white : .black)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}

struct WhiteTilesStyleMini: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: screenWidth*0.048, height: Sizing.s(200), alignment: .bottom)
            .background(isPressed ? .gray : .white)
            .foregroundColor(!isPressed ? .black : .white)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}

struct BlackTilesStyleMini: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: screenWidth*0.042, height: Sizing.s(120), alignment: .bottom)
            .background(isPressed ? .gray : .black)
            .foregroundColor(!isPressed ? .white : .black)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}
