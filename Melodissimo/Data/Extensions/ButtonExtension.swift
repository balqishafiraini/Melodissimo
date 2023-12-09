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
            .frame(width: UIScreen.main.bounds.width*0.048, height: 350, alignment: .bottom)
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
            .frame(width: UIScreen.main.bounds.width*0.042, height: 220, alignment: .bottom)
            .background(isPressed ? .gray : .black)
            .foregroundColor(!isPressed ? .white : .black)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}

struct WhiteTilesStyleMini: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: UIScreen.main.bounds.width*0.048, height: 200, alignment: .bottom)
            .background(isPressed ? .gray : .white)
            .foregroundColor(!isPressed ? .black : .white)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}

struct BlackTilesStyleMini: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(width: UIScreen.main.bounds.width*0.042, height: 120, alignment: .bottom)
            .background(isPressed ? .gray : .black)
            .foregroundColor(!isPressed ? .white : .black)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])

    }
}
