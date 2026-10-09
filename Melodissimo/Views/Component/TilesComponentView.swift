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
/// screens; the mini keyboard is used on the compact song screens.
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
}

// MARK: - Touch tracking

/// The laid-out frame of a single key in the keyboard's coordinate space, used to
/// hit-test the finger location so a drag can slide from one key to the next.
private struct PianoTileInfo: Equatable {
    let id: Int
    let keySound: String
    let isBlack: Bool
    let frame: CGRect
}

/// Collects every key's frame so the parent can hit-test touches against them.
private struct PianoTilePreferenceKey: PreferenceKey {
    static var defaultValue: [PianoTileInfo] = []
    static func reduce(value: inout [PianoTileInfo], nextValue: () -> [PianoTileInfo]) {
        value.append(contentsOf: nextValue())
    }
}

/// A single, passive key. It no longer owns any gesture of its own — all touch
/// handling lives on the parent keyboard so the finger can glide across keys like a
/// real piano. Each key only reports its frame (for hit-testing) and draws itself
/// pressed when it is the one currently under the finger.
private struct KeyTile: View {
    let id: Int
    let keySound: String
    let label: String
    let isBlack: Bool
    let showLabel: Bool
    let metrics: PianoMetrics
    let activeTileID: Int?

    private var isPressed: Bool { activeTileID == id }

    var body: some View {
        let width = isBlack ? metrics.blackWidth : metrics.whiteWidth
        let height = isBlack ? metrics.blackHeight : metrics.whiteHeight

        Text(showLabel ? label : "")
            .font(.subheadline)
            .frame(width: width, height: height, alignment: .bottom)
            .background(isPressed ? Color.gray : (isBlack ? Color.black : Color.white))
            .foregroundColor(isBlack ? (isPressed ? .black : .white) : (isPressed ? .white : .black))
            .cornerRadius(radius: 12, corners: [.bottomLeft, .bottomRight])
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: PianoTilePreferenceKey.self,
                        value: [PianoTileInfo(id: id,
                                              keySound: keySound,
                                              isBlack: isBlack,
                                              frame: geo.frame(in: .named("keyboard")))]
                    )
                }
            )
    }
}

// MARK: - Keyboard

/// The full pianika keyboard. A single `DragGesture` covering the whole keyboard
/// tracks the finger and plays whichever key it is over, switching sounds as the
/// finger slides across keys — no need to lift between notes.
///
/// - `showLabels`: learning screens show the note names; quiz screens hide them.
/// - `isQuiz`: when true, releasing the finger registers the last key as the answer.
private struct PianoKeyboardView: View {
    let metrics: PianoMetrics
    let isQuiz: Bool
    let showLabels: Bool
    var viewModel: TilesViewModel? = nil

    @State private var tiles: [PianoTileInfo] = []
    @State private var activeTileID: Int? = nil

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
        .onPreferenceChange(PianoTilePreferenceKey.self) { tiles = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { handleDrag(at: $0.location) }
                .onEnded { _ in handleEnd() }
        )
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
                       keySound: note.sound,
                       label: note.label,
                       isBlack: note.isBlack,
                       showLabel: showLabels,
                       metrics: metrics,
                       activeTileID: activeTileID)
    }

    // MARK: Touch handling

    /// Which key is under the finger. Black keys sit on top of the white keys, so
    /// they win when both frames contain the point.
    private func tile(at point: CGPoint) -> PianoTileInfo? {
        if let black = tiles.first(where: { $0.isBlack && $0.frame.contains(point) }) {
            return black
        }
        return tiles.first(where: { !$0.isBlack && $0.frame.contains(point) })
    }

    private func handleDrag(at point: CGPoint) {
        let hit = tile(at: point)
        // Only react when the finger crosses into a different key (or off the keyboard),
        // otherwise a stationary press would retrigger the note on every move event.
        guard hit?.id != activeTileID else { return }

        stopSound()
        if let hit {
            playSound(key: hit.keySound)
        }
        activeTileID = hit?.id
    }

    private func handleEnd() {
        stopSound()
        // In a quiz, the key the finger lifts on is the submitted answer.
        if isQuiz, let id = activeTileID {
            viewModel?.addAnswer(id)
        }
        activeTileID = nil
    }
}

// MARK: - Public entry points

struct PianikaStackLearning: View {
    var body: some View {
        PianoKeyboardView(metrics: .full, isQuiz: false, showLabels: true)
    }
}

struct PianikaStackLearningMini: View {
    var body: some View {
        PianoKeyboardView(metrics: .mini, isQuiz: false, showLabels: true)
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

        PianoKeyboardView(metrics: .full, isQuiz: true, showLabels: false, viewModel: viewModel)
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

        PianoKeyboardView(metrics: .mini, isQuiz: true, showLabels: false, viewModel: viewModel)
    }
}
