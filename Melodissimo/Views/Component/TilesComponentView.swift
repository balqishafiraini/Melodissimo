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

    private var whiteRow: some View {
        HStack(spacing: 2) {
            Group {
                key(1, "f1", "4.")
                key(2, "g1", "5.")
                key(3, "a1", "6.")
                key(4, "b1", "7.")
            }
            Group {
                key(5, "c2", "1")
                key(6, "d2", "2")
                key(7, "e2", "3")
                key(8, "f2", "4")
                key(9, "g2", "5")
                key(10, "a2", "6")
                key(11, "b2", "7")
            }
            Group {
                key(12, "c3", "1˙")
                key(13, "d3", "2˙")
                key(14, "e3", "3˙")
                key(15, "f3", "4˙")
                key(16, "g3", "5˙")
                key(17, "a3", "6˙")
                key(18, "b3", "7˙")
            }
            key(19, "c4", "1˙˙")
        }
        .frame(width: screenWidth, height: metrics.whiteRowHeight)
    }

    private var blackRow: some View {
        HStack {
            HStack(spacing: screenWidth * 0.06) {
                HStack {
                    key(20, "f1s", "4.#", isBlack: true)
                    key(21, "g1s", "5.#", isBlack: true)
                    key(22, "a1s", "6.#", isBlack: true)
                }
                HStack {
                    key(23, "c2s", "1#", isBlack: true)
                    key(24, "d2s", "2#", isBlack: true)
                }
                HStack {
                    key(25, "f2s", "4#", isBlack: true)
                    key(26, "g2s", "5#", isBlack: true)
                    key(27, "a2s", "6#", isBlack: true)
                }
                HStack {
                    key(28, "c3s", "1˙#", isBlack: true)
                    key(29, "d3s", "2˙#", isBlack: true)
                }
                HStack {
                    key(30, "f3s", "4˙#", isBlack: true)
                    key(31, "g3s", "5˙#", isBlack: true)
                    key(32, "a3s", "6˙#", isBlack: true)
                }
            }
        }
        .frame(width: screenWidth * 0.88, height: metrics.blackRowHeight, alignment: .topLeading)
    }

    private func key(_ id: Int, _ sound: String, _ label: String, isBlack: Bool = false) -> KeyTile {
        KeyTile(id: id,
                keySound: sound,
                label: label,
                isBlack: isBlack,
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
