//
//  Skins.swift
//  Melodissimo
//
//  The look of the equipped shop items, as SwiftUI values. Models stay free of SwiftUI, so the
//  catalog only says which colours; this file turns them into `Color`s for the keyboard, the
//  falling notes and Alpanica.
//

import SwiftUI

/// The keyboard's body colour and the colour of a pressed key.
struct KeyboardSkin {
    let body: Color
    let pressed: Color

    /// The app's normal navy keyboard with grey pressed keys.
    static let standard = KeyboardSkin(body: .navy, pressed: .gray)

    init(body: Color, pressed: Color) {
        self.body = body
        self.pressed = pressed
    }

    init(item: ShopItem) {
        if item.colors.count == 2 {
            self.init(body: Color(hex: item.colors[0]), pressed: Color(hex: item.colors[1]))
        } else {
            self = .standard
        }
    }

    /// What the player is wearing now.
    static var equipped: KeyboardSkin {
        KeyboardSkin(item: ProgressStore.shared.equippedItem(.keyboard))
    }
}

extension NoteSkin {
    /// What the player is wearing now.
    static var equipped: NoteSkin {
        NoteSkin(itemId: ProgressStore.shared.equippedItem(.notes).id)
    }

    /// The fill of a note on this key, or `nil` for the standard yellow / navy.
    func color(semitone: Int, isBlack: Bool) -> Color? {
        fill(semitone: semitone, isBlack: isBlack).map {
            Color(hue: $0.hue, saturation: $0.saturation, brightness: $0.brightness)
        }
    }
}

extension AlpanicaOutfit {
    /// What Alpanica is wearing now.
    static var equipped: AlpanicaOutfit {
        AlpanicaOutfit(rawValue: ProgressStore.shared.equippedItem(.outfit).variant) ?? .none
    }
}
