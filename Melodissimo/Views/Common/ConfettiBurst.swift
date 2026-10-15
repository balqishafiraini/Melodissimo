//
//  ConfettiBurst.swift
//  Melodissimo
//

import SwiftUI
import QuartzCore

/// Confetti for the result screen: `.confettiBurst(trigger:)` throws a burst each time `trigger` changes. It replaces
/// the ConfettiSwiftUI package. The burst is one `Canvas` in a `TimelineView`, and the whole overlay is removed once
/// the last piece has faded, so after a moment nothing is drawing or ticking. With Reduce Motion there is no confetti.
private struct ConfettiBurstModifier: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Host time the running burst began, or `nil` when none is running.
    @State private var startedAt: CFTimeInterval?
    @State private var pieces: [ConfettiPiece] = []

    private static let palette: [Color] = [.yellow, .softGreen, .softBlue, .red, .darkGreen]

    func body(content: Content) -> some View {
        content
            .overlay {
                if let startedAt {
                    TimelineView(.animation) { timeline in
                        Canvas { context, size in
                            _ = timeline.date   // makes every frame's closure differ, so the canvas redraws
                            draw(&context, size: size, age: CACurrentMediaTime() - startedAt)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .onChange(of: trigger) { newValue in
                guard !reduceMotion else { return }
                let began = CACurrentMediaTime()
                pieces = ConfettiPhysics.pieces(seed: UInt64(truncatingIfNeeded: newValue) &+ 1)
                startedAt = began
                DispatchQueue.main.asyncAfter(deadline: .now() + ConfettiPhysics.totalDuration + 0.1) {
                    // A newer burst has its own end; only the one that started this timer stops it.
                    if startedAt == began { startedAt = nil }
                }
            }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, age: Double) {
        // The physics is in iPad points; a shorter screen throws the confetti proportionally less far.
        let scale = size.height / 820
        let origin = CGPoint(x: size.width / 2, y: size.height)
        for piece in pieces {
            let pieceAge = age - piece.launchDelay
            let opacity = ConfettiPhysics.opacity(at: pieceAge)
            guard opacity > 0 else { continue }
            let offset = ConfettiPhysics.position(of: piece, at: pieceAge)
            let centre = CGPoint(x: origin.x + offset.x * scale, y: origin.y + offset.y * scale)
            let edge = max(6, piece.size * max(scale, 0.6))
            var layer = context
            layer.opacity = opacity
            layer.translateBy(x: centre.x, y: centre.y)
            layer.rotate(by: .radians(ConfettiPhysics.rotation(of: piece, at: pieceAge)))
            let rect = piece.isCircle
                ? CGRect(x: -edge / 2, y: -edge / 2, width: edge, height: edge)
                : CGRect(x: -edge / 2, y: -edge / 4, width: edge, height: edge / 2)
            let shape = piece.isCircle ? Path(ellipseIn: rect) : Path(rect)
            layer.fill(shape, with: .color(Self.palette[piece.colorIndex % Self.palette.count]))
        }
    }
}

extension View {
    /// Throws confetti from the bottom centre each time `trigger` changes (not on the first appearance). It lasts
    /// about 3 s, doesn't take touches, and is skipped with Reduce Motion.
    func confettiBurst(trigger: Int) -> some View {
        modifier(ConfettiBurstModifier(trigger: trigger))
    }
}
