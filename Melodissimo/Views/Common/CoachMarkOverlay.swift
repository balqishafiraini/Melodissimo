//
//  CoachMarkOverlay.swift
//  Melodissimo
//

import SwiftUI

/// Where each coach-mark target is on screen, collected from the views that call `.coachTarget(_:)`.
struct CoachTargetKey: PreferenceKey {
    static var defaultValue: [CoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachTarget: Anchor<CGRect>], nextValue: () -> [CoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

extension View {
    /// Marks this view as something a coach-mark bubble can point at.
    func coachTarget(_ target: CoachTarget) -> some View {
        anchorPreference(key: CoachTargetKey.self, value: .bounds) { [target: $0] }
    }
}

/// A dimmed screen with the current target lit up and a bubble beside it: "These numbers are notes",
/// then Next, then the next bubble. It covers the whole screen, so nothing underneath can be tapped
/// until the tour is done or skipped.
struct CoachMarkOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let steps: [CoachStep]
    /// Target frames in this overlay's own coordinate space.
    let frames: [CoachTarget: CGRect]
    let onFinish: () -> Void

    @State private var index = 0

    private var step: CoachStep { steps[min(index, steps.count - 1)] }
    private var isLast: Bool { index >= steps.count - 1 }
    private var highlight: CGRect? { frames[step.target]?.insetBy(dx: -10, dy: -10) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                dimming(in: geo.size)
                bubble(in: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    /// Black at 60 % with a rounded hole over the target, so it stands out.
    private func dimming(in size: CGSize) -> some View {
        Canvas { context, canvasSize in
            var path = Path(CGRect(origin: .zero, size: canvasSize))
            if let highlight {
                path.addRoundedRect(in: highlight, cornerSize: CGSize(width: 24, height: 24))
            }
            context.fill(path, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
            if let highlight {
                context.stroke(Path(roundedRect: highlight, cornerRadius: 24), with: .color(Color.yellow), lineWidth: 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {}   // swallows taps, so the screen underneath stays still
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: index)
    }

    private func bubble(in size: CGSize) -> some View {
        let width: CGFloat = 520
        let height: CGFloat = 250
        let center = bubbleCenter(width: width, height: height, in: size)
        return VStack(spacing: 14) {
            HStack(spacing: 16) {
                AssetImage(name: "alpanica_happy", fallbackEmoji: "🦙")
                    .frame(width: 90, height: 90)
                Text(LocalizedStringKey(step.text))
                    .font(.custom("BalooDa-Regular", size: 30))
                    .foregroundColor(Color.darkGreen)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                // Dots show which bubble this is.
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { dot in
                        Circle()
                            .fill(dot == index ? Color.darkGreen : Color.darkGreen.opacity(0.25))
                            .frame(width: 12, height: 12)
                    }
                }
                Spacer()
                if !isLast {
                    SoundButton(action: onFinish) {
                        Text("Skip")
                            .padding(.horizontal, 22)
                            .frame(height: 52)
                            .foregroundColor(Color.darkGreen)
                            .font(Font.headline)
                    }
                }
                SoundButton {
                    if isLast {
                        onFinish()
                    } else {
                        index += 1
                    }
                } label: {
                    Text(isLast ? "Got it!" : "Next")
                        .padding(.horizontal, 30)
                        .frame(height: 52)
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .font(Font.headline)
                }
            }
        }
        .padding(24)
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: 32).fill(Color.white))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .position(center)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: index)
    }

    /// Beside the target: above it when there is room, otherwise below, kept inside the screen.
    private func bubbleCenter(width: CGFloat, height: CGFloat, in size: CGSize) -> CGPoint {
        guard let target = highlight else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        let margin: CGFloat = 24
        let x = min(max(target.midX, width / 2 + margin), size.width - width / 2 - margin)
        let above = target.minY - margin - height / 2
        let below = target.maxY + margin + height / 2
        let y = above - height / 2 >= margin ? above : min(below, size.height - height / 2 - margin)
        return CGPoint(x: x, y: y)
    }
}
