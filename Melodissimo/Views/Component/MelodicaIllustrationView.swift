//
//  MelodicaIllustrationView.swift
//  Melodissimo
//
//  A non-interactive melodica keyboard drawn in code. It scales to whatever
//  size it's given, so it's used by the splash screen and the tutorial slides
//  instead of fixed-size pictures that only fit the iPad.
//

import SwiftUI

struct MelodicaIllustrationView: View {
    /// Show the numeral notation on each key (like the learn screens).
    var showsLabels = false
    /// White key index (0...18) drawn as pressed, if any.
    var pressedWhiteKey: Int? = nil
    /// Show the "MELODISSIMO" brand on the left of the body.
    var showsBrand = false

    static let whiteLabels = ["4.", "5.", "6.", "7.", "1", "2", "3", "4", "5", "6", "7",
                              "1˙", "2˙", "3˙", "4˙", "5˙", "6˙", "7˙", "1˙˙"]
    /// White key index each black key sits after, with its label.
    static let blackKeys: [(after: Int, label: String)] = [
        (0, "4.#"), (1, "5.#"), (2, "6.#"),
        (4, "1#"), (5, "2#"),
        (7, "4#"), (8, "5#"), (9, "6#"),
        (11, "1˙#"), (12, "2˙#"),
        (14, "4˙#"), (15, "5˙#"), (16, "6˙#"),
    ]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let border = min(size.height * 0.08, size.width * 0.02)
            let brandWidth = showsBrand ? size.height * 0.12 : 0
            let keysWidth = size.width - border * 2 - brandWidth
            let keysHeight = size.height - border * 2
            let whiteWidth = keysWidth / CGFloat(Self.whiteLabels.count)
            let blackWidth = whiteWidth * 0.62
            let blackHeight = keysHeight * 0.62
            let labelSize = max(6, min(whiteWidth * 0.38, keysHeight * 0.1))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: size.height * 0.1, style: .continuous)
                    .fill(Color.navy)
                    .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: size.height * 0.02)

                if showsBrand {
                    Text("MELODISSIMO")
                        .font(.custom("BalooDa-Regular", size: brandWidth * 0.55))
                        .foregroundColor(.black.opacity(0.25))
                        .lineLimit(1)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: brandWidth, height: size.height)
                        .offset(x: border * 0.5)
                }

                // White keys
                HStack(spacing: 0) {
                    ForEach(Self.whiteLabels.indices, id: \.self) { index in
                        let isPressed = pressedWhiteKey == index
                        Rectangle()
                            .fill(isPressed ? Color.gray : Color.white)
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(Color.navy.opacity(0.8)).frame(width: max(0.5, whiteWidth * 0.03))
                            }
                            .overlay(alignment: .bottom) {
                                if showsLabels {
                                    Text(Self.whiteLabels[index])
                                        .font(.custom("BalooDa-Regular", size: labelSize))
                                        .foregroundColor(isPressed ? .white : .black)
                                        .padding(.bottom, keysHeight * 0.04)
                                }
                            }
                    }
                }
                .frame(width: keysWidth, height: keysHeight)
                .clipShape(RoundedRectangle(cornerRadius: whiteWidth * 0.15))
                .offset(x: border + brandWidth, y: border)

                // Black keys
                ForEach(Self.blackKeys, id: \.after) { key in
                    RoundedRectangle(cornerRadius: blackWidth * 0.18)
                        .fill(Color(white: 0.1))
                        .frame(width: blackWidth, height: blackHeight)
                        .overlay(alignment: .bottom) {
                            if showsLabels {
                                Text(key.label)
                                    .font(.custom("BalooDa-Regular", size: labelSize * 0.85))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .padding(.bottom, keysHeight * 0.03)
                            }
                        }
                        .offset(x: border + brandWidth + whiteWidth * CGFloat(key.after + 1) - blackWidth / 2,
                                y: border)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        MelodicaIllustrationView(showsBrand: true)
            .frame(width: 700, height: 200)
        MelodicaIllustrationView(showsLabels: true, pressedWhiteKey: 2)
            .frame(width: 700, height: 220)
    }
    .padding()
    .background(Color.softBlue)
}
