//
//  TilesComponentView.swift
//  Melodissimo
//
//  Created by Balqis on 09/12/23.
//

import Foundation
import SwiftUI

// MARK: - Keyboard geometry

/// Sizing for one keyboard variant. The full keyboard is used on the big play
/// screens; the mini keyboard is used on the compact song screens; the stage keyboard sits under the note highway.
struct PianoMetrics {
    let whiteWidth = screenWidth * 0.048
    let blackWidth = screenWidth * 0.042
    let whiteHeight: CGFloat
    let blackHeight: CGFloat
    let containerHeight: CGFloat
    let whiteRowHeight: CGFloat
    let blackRowHeight: CGFloat

    static let full = PianoMetrics(whiteHeight: 350, blackHeight: 220,
                                   containerHeight: 450, whiteRowHeight: 450, blackRowHeight: 350)
    static let mini = PianoMetrics(whiteHeight: 200, blackHeight: 120,
                                   containerHeight: 300, whiteRowHeight: 300, blackRowHeight: 200)
    /// A shorter keyboard for the song stage, leaving room for the falling notes above it.
    static let stage = PianoMetrics(whiteHeight: 230, blackHeight: 145,
                                    containerHeight: 290, whiteRowHeight: 290, blackRowHeight: 230)
}

// MARK: - Touch tracking

/// The laid-out frame of a single key, used to hit-test finger locations so a finger
/// can slide from one key to the next, and to tell the note highway where each lane is.
private struct PianoTileInfo: Equatable {
    let id: Int
    let isBlack: Bool
    /// In the keyboard's own coordinate space (the touch surface's local space).
    let frame: CGRect
    /// In the window's coordinate space, reported to the note highway.
    let globalFrame: CGRect
}

/// Collects every key's frame so the parent can hit-test touches against them.
private struct PianoTilePreferenceKey: PreferenceKey {
    static var defaultValue: [PianoTileInfo] = []
    static func reduce(value: inout [PianoTileInfo], nextValue: () -> [PianoTileInfo]) {
        value.append(contentsOf: nextValue())
    }
}

/// A single, passive key. It owns no gesture — all touch handling lives on the keyboard's
/// touch surface so several fingers can play at once and glide across keys like a real
/// piano. Each key only reports its frames and draws itself.
private struct KeyTile: View {
    let id: Int
    let label: String
    let isBlack: Bool
    let showLabel: Bool
    let metrics: PianoMetrics
    let isPressed: Bool
    /// A tint that wins over the pressed look: a hint glow, a correct (green) or wrong (red) flash.
    let highlight: Color?

    private var keyColor: Color {
        if let highlight { return highlight }
        if isPressed { return .gray }
        return isBlack ? .black : .white
    }

    private var textColor: Color {
        if highlight == nil, isPressed { return isBlack ? .black : .white }
        return isBlack ? .white : .black
    }

    var body: some View {
        let width = isBlack ? metrics.blackWidth : metrics.whiteWidth
        let height = isBlack ? metrics.blackHeight : metrics.whiteHeight

        Text(showLabel ? label : "")
            .font(.subheadline)
            .frame(width: width, height: height, alignment: .bottom)
            .background(keyColor)
            .foregroundColor(textColor)
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: PianoTilePreferenceKey.self,
                        value: [PianoTileInfo(id: id,
                                              isBlack: isBlack,
                                              frame: geo.frame(in: .named("keyboard")),
                                              globalFrame: geo.frame(in: .global))]
                    )
                }
            )
    }
}

/// A transparent UIKit surface laid over the keyboard that tracks every finger separately.
/// Its local coordinates are the keyboard's "keyboard" coordinate space, so the key frames
/// collected by the preference key can be hit-tested against touch locations directly.
private struct MultiTouchKeySurface: UIViewRepresentable {
    let tiles: [PianoTileInfo]
    let onKeyDown: (Int) -> Void
    let onKeyUp: (_ id: Int, _ isRelease: Bool) -> Void

    func makeUIView(context: Context) -> TouchView {
        TouchView()
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.tiles = tiles
        view.onKeyDown = onKeyDown
        view.onKeyUp = onKeyUp
    }

    final class TouchView: UIView {
        var tiles: [PianoTileInfo] = []
        var onKeyDown: (Int) -> Void = { _ in }
        var onKeyUp: (Int, Bool) -> Void = { _, _ in }

        /// Which key each finger is currently on.
        private var keyForTouch: [ObjectIdentifier: Int] = [:]

        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        /// Black keys sit on top of the white keys, so they win when both frames contain the point.
        private func keyID(at point: CGPoint) -> Int? {
            if let black = tiles.first(where: { $0.isBlack && $0.frame.contains(point) }) {
                return black.id
            }
            return tiles.first(where: { !$0.isBlack && $0.frame.contains(point) })?.id
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                guard let id = keyID(at: touch.location(in: self)) else { continue }
                keyForTouch[ObjectIdentifier(touch)] = id
                onKeyDown(id)
            }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                let touchID = ObjectIdentifier(touch)
                let old = keyForTouch[touchID]
                let new = keyID(at: touch.location(in: self))
                // Only react when the finger crosses into a different key (or off the keyboard),
                // otherwise a stationary press would retrigger the note on every move event.
                guard new != old else { continue }
                if let old { onKeyUp(old, false) }
                keyForTouch[touchID] = new
                if let new { onKeyDown(new) }
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                if let id = keyForTouch.removeValue(forKey: ObjectIdentifier(touch)) {
                    onKeyUp(id, true)
                }
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                if let id = keyForTouch.removeValue(forKey: ObjectIdentifier(touch)) {
                    onKeyUp(id, false)
                }
            }
        }
    }
}

// MARK: - Keyboard

/// The pianika keyboard: 32 keys that any number of fingers can play at once, and that a
/// finger can glide across to switch notes without lifting.
///
/// - `showLabels`: learning screens show the note names; quiz screens hide them.
/// - `highlights`: key id → tint (hint glow, correct / wrong flash).
/// - `playsSound`: `false` when something else produces the sound (autoplay, microphone mode).
/// - `onNoteOn`: a key went down (a touch began or slid onto it).
/// - `onNoteOff`: a key went up; `isRelease` is true when the finger lifted on it and false when it slid away or the touch was cancelled.
/// - `onKeyFrames`: every key's frame in the window's coordinate space, reported when the layout changes.
/// - `pressedFromOutside`: keys drawn pressed by something other than touch (autoplay).
struct PianoKeyboard: View {
    var metrics: PianoMetrics
    var showLabels: Bool
    var highlights: [Int: Color] = [:]
    var playsSound = true
    var onNoteOn: ((Int) -> Void)? = nil
    var onNoteOff: ((_ id: Int, _ isRelease: Bool) -> Void)? = nil
    var onKeyFrames: (([Int: CGRect]) -> Void)? = nil
    var pressedFromOutside: Set<Int> = []

    @State private var tiles: [PianoTileInfo] = []
    @State private var activeTileIDs: Set<Int> = []
    /// How many fingers are on each key, so a key stays down until the last one lifts.
    @State private var fingersOnKey: [Int: Int] = [:]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.navy)
                .padding()
                .frame(width: screenWidth, height: metrics.containerHeight)
                .cornerRadius(50)

            whiteRow
            blackRow
        }
        .frame(maxWidth: .infinity, minHeight: metrics.containerHeight, alignment: .topLeading)
        .coordinateSpace(name: "keyboard")
        .onPreferenceChange(PianoTilePreferenceKey.self) { newTiles in
            tiles = newTiles
            onKeyFrames?(Dictionary(newTiles.map { ($0.id, $0.globalFrame) }, uniquingKeysWith: { _, latest in latest }))
        }
        .overlay(
            MultiTouchKeySurface(tiles: tiles, onKeyDown: handleKeyDown, onKeyUp: handleKeyUp)
        )
        .onDisappear(perform: releaseAllKeys)
    }

    /// The black keys sit in the gaps between white keys, so they're laid out in the
    /// same five groups as the physical pianika (2 + 3 spacing pattern).
    private static let blackKeyGroups: [[Int]] = [
        [20, 21, 22],
        [23, 24],
        [25, 26, 27],
        [28, 29],
        [30, 31, 32]
    ]

    private var whiteRow: some View {
        HStack(spacing: 2) {
            ForEach(NoteCatalog.whiteKeyIDs, id: \.self) { id in
                key(id)
            }
        }
        .frame(width: screenWidth, height: metrics.whiteRowHeight)
    }

    private var blackRow: some View {
        HStack {
            HStack(spacing: screenWidth * 0.06) {
                ForEach(Self.blackKeyGroups.indices, id: \.self) { group in
                    HStack {
                        ForEach(Self.blackKeyGroups[group], id: \.self) { id in
                            key(id)
                        }
                    }
                }
            }
        }
        .frame(width: screenWidth * 0.88, height: metrics.blackRowHeight, alignment: .topLeading)
    }

    private func key(_ id: Int) -> KeyTile {
        let note = NoteCatalog.note(id)
        return KeyTile(id: id,
                       label: note.label,
                       isBlack: note.isBlack,
                       showLabel: showLabels,
                       metrics: metrics,
                       isPressed: activeTileIDs.contains(id) || pressedFromOutside.contains(id),
                       highlight: highlights[id])
    }

    // MARK: Touch handling

    private func handleKeyDown(_ id: Int) {
        fingersOnKey[id, default: 0] += 1
        activeTileIDs.insert(id)
        if playsSound {
            playSound(key: NoteCatalog.note(id).sound)
        }
        onNoteOn?(id)
    }

    private func handleKeyUp(_ id: Int, isRelease: Bool) {
        let remaining = max(0, (fingersOnKey[id] ?? 1) - 1)
        if remaining == 0 {
            fingersOnKey[id] = nil
            activeTileIDs.remove(id)
            if playsSound {
                stopSound(key: NoteCatalog.note(id).sound)
            }
        } else {
            fingersOnKey[id] = remaining
        }
        onNoteOff?(id, isRelease)
    }

    /// Leaving the screen with fingers down must not leave a note ringing.
    private func releaseAllKeys() {
        if playsSound {
            for id in activeTileIDs {
                stopSound(key: NoteCatalog.note(id).sound)
            }
        }
        activeTileIDs = []
        fingersOnKey = [:]
    }
}

// MARK: - Public entry points

struct PianikaStackLearning: View {
    var body: some View {
        PianoKeyboard(metrics: .full, showLabels: true)
    }
}

struct PianikaStackLearningMini: View {
    var body: some View {
        PianoKeyboard(metrics: .mini, showLabels: true)
    }
}

struct PianikaStackQuiz: View {

    @ObservedObject var viewModel: TilesViewModel

    /// Legacy flows (preplay/postplay) still push the result screen from here via a
    /// `NavigationLink`. The router-driven game flow sets this to `false` and pushes
    /// the result route itself, so there's no double navigation.
    var autoNavigateOnFinish = true

    var body: some View {
        if autoNavigateOnFinish {
            NavigationLink(destination: AfterQuizView(level: viewModel.currentLevel, userAnswer: viewModel.answers, userScore: viewModel.score).navigationBarBackButtonHidden(true), isActive: $viewModel.canNavigateToAfterQuizPage) {
                Text("")
            }
        }

        // In a quiz, the key the finger lifts on is the submitted answer.
        PianoKeyboard(metrics: .full, showLabels: false, onNoteOff: { id, isRelease in
            if isRelease { viewModel.addAnswer(id) }
        })
    }
}

struct PianikaStackQuizMini: View {

    @ObservedObject var viewModel: TilesViewModel

    /// See `PianikaStackQuiz.autoNavigateOnFinish`.
    var autoNavigateOnFinish = true

    var body: some View {
        if autoNavigateOnFinish {
            NavigationLink(destination: AfterQuizView(level: viewModel.currentLevel, userAnswer: viewModel.answers, userScore: viewModel.score).navigationBarBackButtonHidden(true), isActive: $viewModel.canNavigateToAfterQuizPage) {
                Text("")
            }
        }

        PianoKeyboard(metrics: .mini, showLabels: false, onNoteOff: { id, isRelease in
            if isRelease { viewModel.addAnswer(id) }
        })
    }
}
