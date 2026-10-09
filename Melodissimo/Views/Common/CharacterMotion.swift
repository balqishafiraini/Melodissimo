//
//  CharacterMotion.swift
//  Melodissimo
//
//  Reusable animations for Alpanica and the Fals monsters. Every effect is a
//  view modifier so any image can use it, and every one is skipped when the
//  player has Reduce Motion turned on.
//

import SwiftUI

// MARK: - Looping idle motion

/// Gentle squash-and-stretch "breathing", anchored at the feet.
private struct IdleBreathe: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false
    var period: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: inhale ? 1.02 : 1, y: inhale ? 0.97 : 1, anchor: .bottom)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) {
                    inhale = true
                }
            }
    }
}

/// Side-to-side "off-key" wobble used by the Fals monsters.
private struct Wobble: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilted = false
    var degrees: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(tilted ? degrees : -degrees), anchor: .bottom)
            .scaleEffect(x: tilted ? 0.97 : 1.03, y: tilted ? 1.03 : 0.97, anchor: .bottom)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    tilted = true
                }
            }
    }
}

/// Slow up-and-down float, for map avatars and menu decorations.
private struct GentleFloat: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false
    var distance: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -distance : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}

// MARK: - Triggered reactions

/// Squash, leap, land: plays each time `trigger` changes (for example a correct answer count).
private struct Hop<T: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var trigger: T
    var height: CGFloat
    @State private var lift: CGFloat = 0
    @State private var squash: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 2 - squash, y: squash, anchor: .bottom)
            .offset(y: -lift)
            .onChange(of: trigger) { _ in
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.08)) { squash = 0.88 }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.08)) {
                    squash = 1.06
                    lift = height
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45).delay(0.3)) {
                    squash = 1
                    lift = 0
                }
            }
    }
}

/// Bright flash plus a quick shake: plays each time `trigger` changes (a hit landed).
private struct HitShake<T: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var trigger: T
    @State private var shake: CGFloat = 0
    @State private var flash = false

    func body(content: Content) -> some View {
        content
            .brightness(flash ? 0.35 : 0)
            .modifier(ShakeEffect(travel: shake))
            .onChange(of: trigger) { _ in
                flash = true
                withAnimation(.easeOut(duration: 0.25)) { flash = false }
                guard !reduceMotion else { return }
                shake = 0
                withAnimation(.linear(duration: 0.35)) { shake = 1 }
            }
    }
}

/// Damped horizontal shake driven by an animatable 0→1 progress value.
private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = sin(travel * .pi * 6) * 14 * (1 - travel)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

extension View {
    func idleBreathe(period: Double = 2.4) -> some View { modifier(IdleBreathe(period: period)) }
    func wobble(degrees: Double = 6) -> some View { modifier(Wobble(degrees: degrees)) }
    func gentleFloat(distance: CGFloat = 8) -> some View { modifier(GentleFloat(distance: distance)) }
    func hop<T: Equatable>(on trigger: T, height: CGFloat = 60) -> some View { modifier(Hop(trigger: trigger, height: height)) }
    func hitShake<T: Equatable>(on trigger: T) -> some View { modifier(HitShake(trigger: trigger)) }
}

// MARK: - Floating text

/// "−1", "+10" or "Perfect!" that rises and fades each time `trigger` changes.
struct FloatingText<T: Equatable>: View {
    var text: String
    var color: Color = .red
    var trigger: T
    @State private var rise: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Text(text)
            .font(.custom("BalooDa-Regular", size: 40))
            .foregroundColor(color)
            .shadow(color: .white, radius: 2)
            .offset(y: -rise)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _ in
                rise = 0
                opacity = 1
                withAnimation(.easeOut(duration: 0.9)) {
                    rise = 70
                    opacity = 0
                }
            }
    }
}

// MARK: - Characters

/// Alpanica's outfits, matching the `alpanica_outfit_*` assets.
enum AlpanicaOutfit: String, CaseIterable {
    case none, glasses, crown, royal

    var assetName: String {
        self == .none ? "alpanica" : "alpanica_outfit_\(rawValue)"
    }
}

/// Alpanica's moods. Pose art overrides the outfit for a moment, then returns to it.
enum AlpanicaMood {
    case idle, happy, attack, sad

    func assetName(outfit: AlpanicaOutfit) -> String {
        switch self {
        case .idle: return outfit.assetName
        case .happy: return "alpanica_happy"
        case .attack: return "alpanica_attack"
        case .sad: return "alpanicaSad"
        }
    }
}

/// Alpanica with idle breathing; she hops whenever `hopTrigger` changes.
struct AlpanicaView<T: Equatable>: View {
    var mood: AlpanicaMood = .idle
    var outfit: AlpanicaOutfit = .none
    var hopTrigger: T
    var height: CGFloat = 260

    var body: some View {
        Image(mood.assetName(outfit: outfit))
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .idleBreathe()
            .hop(on: hopTrigger, height: height * 0.25)
    }
}

/// A Fals monster that wobbles and flashes, with a damage number, when `hitTrigger` changes.
/// `kind` is 1–3 for minions; set `isBoss` for the island bosses (1–6).
struct FalsView<T: Equatable>: View {
    var kind: Int = 1
    var isBoss = false
    var hitTrigger: T
    var height: CGFloat = 240

    var body: some View {
        ZStack(alignment: .top) {
            Image(isBoss ? "fals_boss_\(kind)" : "fals_minion_\(kind)")
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .wobble()
                .hitShake(on: hitTrigger)
            FloatingText(text: "−1", trigger: hitTrigger)
        }
    }
}

#if DEBUG
/// Tap the buttons to try every animation in Xcode's canvas or the simulator.
struct CharacterMotionPlayground: View {
    @State private var hops = 0
    @State private var hits = 0

    var body: some View {
        VStack(spacing: 30) {
            HStack(alignment: .bottom, spacing: 60) {
                AlpanicaView(mood: hops % 2 == 0 ? .idle : .happy, outfit: .royal, hopTrigger: hops)
                FalsView(kind: 1, hitTrigger: hits)
                FalsView(kind: 6, isBoss: true, hitTrigger: hits, height: 300)
            }
            HStack(spacing: 20) {
                Button("Correct!") { hops += 1 }
                Button("Hit Fals") { hits += 1 }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Image("stage_bg_concert").resizable().scaledToFill().ignoresSafeArea())
    }
}

struct CharacterMotionPlayground_Previews: PreviewProvider {
    static var previews: some View {
        CharacterMotionPlayground()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
#endif
