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
            .onDisappear {
                // A repeat-forever animation keeps running on a screen that is merely covered (Home under a song);
                // replacing it with an unanimated change stops it. `onAppear` starts it again.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { inhale = false }
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
            .onDisappear {
                // A repeat-forever animation keeps running on a screen that is merely covered (Home under a song);
                // replacing it with an unanimated change stops it. `onAppear` starts it again.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { tilted = false }
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
            .onDisappear {
                // A repeat-forever animation keeps running on a screen that is merely covered (Home under a song);
                // replacing it with an unanimated change stops it. `onAppear` starts it again.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { up = false }
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

/// What Alpanica wears: a full picture (shop card, certificate) and the outfit alone on a clear canvas the size
/// of the pose art, which `AlpanicaView` lays over whatever pose she is in. Built from the equipped shop item,
/// so a new outfit is data (`shop.json`) plus two images, never a new case.
struct AlpanicaOutfit: Hashable {
    /// The shop item id (`outfit_bow`); `outfit_none` for no outfit.
    let id: String
    let preview: ArtSource
    let overlay: ArtSource?

    static let none = AlpanicaOutfit(id: "outfit_none", preview: .asset("alpanica"), overlay: nil)

    /// An outfit item's art: downloaded files first (`fileURL`), then the bundled names. An item without a
    /// picture of its own looks like no outfit.
    init(item: ShopItem, fileURL: (String) -> URL? = { _ in nil }) {
        id = item.id
        preview = item.previewArt(fileURL: fileURL) ?? .asset("alpanica")
        overlay = item.overlayArt(fileURL: fileURL)
    }

    private init(id: String, preview: ArtSource, overlay: ArtSource?) {
        self.id = id
        self.preview = preview
        self.overlay = overlay
    }
}

/// Alpanica's moods: each has its own face, and most have their own motion and floating extras.
/// The outfit stays on in every mood.
enum AlpanicaMood: CaseIterable {
    case idle, happy, attack, sad, surprised, sing, sleepy, love, dizzy, think

    var assetName: String {
        switch self {
        case .idle: return "alpanica"
        case .happy: return "alpanica_happy"
        case .attack: return "alpanica_attack"
        case .sad: return "alpanicaSad"
        case .surprised: return "alpanica_surprised"
        case .sing: return "alpanica_sing"
        case .sleepy: return "alpanica_sleepy"
        case .love: return "alpanica_love"
        case .dizzy: return "alpanica_dizzy"
        case .think: return "alpanica_think"
        }
    }

    /// The short flourishes she plays now and then while idling on screens that allow it.
    static let fidgets: [AlpanicaMood] = [.sing, .think, .love, .happy]
}

/// How Alpanica gets about. Walking and running flip through leg frames (`alpanica_walk_*`, `alpanica_run_*`).
enum AlpanicaGait: CaseIterable {
    case stand, walk, run

    /// The leg frames of one full stride, in order.
    var frames: [String] {
        switch self {
        case .stand: return ["alpanica"]
        case .walk: return ["alpanica_walk_1", "alpanica_walk_2", "alpanica_walk_3", "alpanica_walk_2"]
        case .run: return ["alpanica_run_1", "alpanica_run_2", "alpanica_run_3", "alpanica_run_2"]
        }
    }

    /// Seconds each frame shows.
    var frameTime: Double { self == .run ? 0.085 : 0.16 }
}

/// Alpanica with idle breathing and blinking; she hops whenever `hopTrigger` changes.
struct AlpanicaView<T: Equatable>: View {
    var mood: AlpanicaMood = .idle
    var outfit: AlpanicaOutfit = .none
    var hopTrigger: T
    var height: CGFloat = 260
    /// While idle, now and then sing, think or beam for a moment. For calm screens like Home and the map.
    var fidgets = false
    /// Walking or running in place; move the view to make her travel. Her face follows the gait, not `mood`.
    var gait: AlpanicaGait = .stand
    /// The art faces left; set this to mirror her, for example when she walks to the right.
    var facesRight = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Width over height of all the Alpanica art.
    static var aspect: CGFloat { 443.592 / 612.558 }

    @State private var isBlinking = false
    @State private var fidget: AlpanicaMood?

    private var shownMood: AlpanicaMood {
        mood == .idle ? fidget ?? .idle : mood
    }

    var body: some View {
        Group {
            if gait == .stand {
                figure(shownMood == .idle && isBlinking ? "alpanica_blink" : shownMood.assetName)
                    .overlay(MoodParticles(mood: shownMood, height: height))
                    .modifier(MoodMotion(mood: shownMood, height: height))
                    .idleBreathe(period: shownMood == .sleepy ? 3.6 : 2.4)
            } else {
                TimelineView(.animation(minimumInterval: gait.frameTime / 3, paused: reduceMotion)) { context in
                    gaitFrame(at: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .scaleEffect(x: facesRight ? -1 : 1)
        .hop(on: hopTrigger, height: height * 0.25)
        .task(id: [mood.hashValue, gait.hashValue]) { await blinkAndFidget() }
    }

    /// The pose art with the outfit laid on top.
    private func figure(_ art: String) -> some View {
        ZStack {
            Image(art)
                .resizable()
                .scaledToFit()
            if let overlay = outfit.overlay {
                ArtImage(source: overlay, fallbackEmoji: "")
            }
        }
        .frame(height: height)
    }

    /// One moment of a walk or run: the leg frame, plus a bob on each footfall and a lean into the run.
    private func gaitFrame(at time: Double) -> some View {
        let frames = gait.frames
        let cycle = gait.frameTime * Double(frames.count)
        let step = Int(time / gait.frameTime) % frames.count
        let wave = sin(time / cycle * 2 * .pi)
        // A walk bobs on both footfalls of a stride; a gallop bounds once, off the ground.
        let lift = gait == .run ? max(0, wave) * 0.045 : abs(wave) * 0.012
        return figure(frames[step])
            .rotationEffect(.degrees(gait == .run ? -5 + 2 * wave : 0), anchor: .bottom)
            .offset(y: -height * CGFloat(lift))
    }

    /// Blinks every few seconds while idle and, if allowed, slips into a short flourish now and then.
    private func blinkAndFidget() async {
        isBlinking = false
        fidget = nil
        guard mood == .idle, gait == .stand else { return }
        var blinksUntilFidget = Int.random(in: 3...5)
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 2_200_000_000...4_500_000_000))
            guard !Task.isCancelled else { return }
            if fidgets, blinksUntilFidget == 0 {
                fidget = AlpanicaMood.fidgets.randomElement()
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                fidget = nil
                blinksUntilFidget = Int.random(in: 3...5)
            } else {
                isBlinking = true
                try? await Task.sleep(nanoseconds: 130_000_000)
                isBlinking = false
                blinksUntilFidget -= 1
            }
        }
    }
}

// MARK: - Mood motion and extras

/// The whole-body motion of each mood: swaying while she sings, a heartbeat when in love, a slow nod
/// when sleepy, a slump when sad, a jolt when surprised, a lunge on attack. Still under Reduce Motion.
private struct MoodMotion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var mood: AlpanicaMood
    var height: CGFloat
    @State private var start = Date()

    private var isStill: Bool { reduceMotion || mood == .idle || mood == .happy }

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: isStill)) { context in
            let pose = isStill ? .rest : Pose(mood: mood, time: context.date.timeIntervalSince(start), height: height)
            content
                .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
                .rotationEffect(.degrees(pose.angle), anchor: .bottom)
                .offset(x: pose.x, y: pose.y)
        }
        .onChange(of: mood) { _ in start = Date() }
    }

    private struct Pose {
        var angle = 0.0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        var x: CGFloat = 0
        var y: CGFloat = 0

        static let rest = Pose()

        init() {}

        init(mood: AlpanicaMood, time t: Double, height: CGFloat) {
            /// 0 → 1 → 0 over `length` seconds, then 0: a one-off bump when the mood begins.
            func bump(_ length: Double) -> CGFloat { t < length ? CGFloat(sin(t / length * .pi)) : 0 }
            func wave(_ period: Double) -> Double { sin(t / period * 2 * .pi) }

            switch mood {
            case .idle, .happy:
                break
            case .sing:
                angle = 4 * wave(0.9)
                y = -height * 0.02 * CGFloat(abs(wave(0.9)))
            case .love:
                let beat = CGFloat(pow(max(0, wave(0.8)), 6))
                scaleX = 1 + 0.04 * beat
                scaleY = 1 + 0.04 * beat
            case .sleepy:
                angle = -2 + 2 * wave(3.6)
            case .sad:
                scaleY = 1 - 0.04 * min(1, CGFloat(t / 0.3))
                angle = -2 * min(1, t / 0.3)
            case .dizzy:
                angle = 5 * wave(1.1)
                x = height * 0.015 * CGFloat(wave(0.55))
            case .think:
                angle = 2.5 * min(1, t / 0.4) + 0.6 * wave(2.4)
            case .surprised:
                y = -height * 0.08 * bump(0.3)
                scaleY = 1 + 0.06 * bump(0.3)
                scaleX = 1 - 0.04 * bump(0.3)
            case .attack:
                x = height * 0.06 * bump(0.25)
                angle = 4 * Double(bump(0.25))
            }
        }
    }
}

/// Little things that drift around Alpanica's head: notes when she sings, hearts in love, Zzz when
/// sleepy, sparkles when happy and stars circling when dizzy. Frozen mid-air under Reduce Motion.
private struct MoodParticles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var mood: AlpanicaMood
    var height: CGFloat

    private struct Style {
        var symbols: [String]
        var colors: [Color]
        var period: Double
        var orbits = false
    }

    private var style: Style? {
        switch mood {
        case .sing:
            return Style(symbols: ["music.note", "music.quarternote.3", "music.note"],
                         colors: [Color(hex: 0xFF6B8B), Color(hex: 0x5AA0E0), Color(hex: 0xF2A33A)], period: 1.6)
        case .love:
            return Style(symbols: ["heart.fill", "heart.fill", "heart.fill"],
                         colors: [Color(hex: 0xFF4D7D), Color(hex: 0xFF8FB4), Color(hex: 0xFF4D7D)], period: 1.8)
        case .sleepy:
            return Style(symbols: ["zzz", "zzz"], colors: [Color(hex: 0x8F6AD8), Color(hex: 0xB597EE)], period: 2.6)
        case .happy:
            return Style(symbols: ["sparkle", "sparkle", "sparkle"], colors: [Color(hex: 0xFFD34D)], period: 1.2)
        case .dizzy:
            return Style(symbols: ["star.fill", "star.fill", "star.fill"], colors: [Color(hex: 0xFFD34D)], period: 1.4, orbits: true)
        default:
            return nil
        }
    }

    var body: some View {
        if let style {
            let size = CGSize(width: height * AlpanicaView<Int>.aspect, height: height)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let time = reduceMotion ? style.period * 0.4 : context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<style.symbols.count, id: \.self) { index in
                        particle(index, of: style, time: time, in: size)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func particle(_ index: Int, of style: Style, time: Double, in size: CGSize) -> some View {
        let count = Double(style.symbols.count)
        let phase = (time / style.period + Double(index) / count).truncatingRemainder(dividingBy: 1)
        let glyph = Image(systemName: style.symbols[index])
            .font(.system(size: size.height * (style.orbits ? 0.045 : 0.07), weight: .bold))
            .foregroundColor(style.colors[index % style.colors.count])
            .shadow(color: .white, radius: 1)

        if style.orbits {
            // Round the top of her head, in front on the lower half of the loop.
            let angle = phase * 2 * .pi
            return glyph
                .scaleEffect(0.75 + 0.35 * sin(angle))
                .position(x: size.width * (0.24 + 0.19 * cos(angle)), y: size.height * (0.05 + 0.025 * sin(angle)))
                .opacity(1)
        }
        // Rise from beside her head, drifting and fading.
        let lane = Double(index) / max(1, count - 1)
        let x = size.width * (0.42 + 0.14 * lane) + size.width * 0.03 * sin(phase * 2 * .pi + Double(index))
        let y = size.height * (0.24 - 0.2 * phase)
        return glyph
            .scaleEffect(0.6 + 0.6 * phase)
            .position(x: x, y: y)
            .opacity(sin(phase * .pi))
    }
}

/// A Fals monster that wobbles and flashes, with a damage number, when `hitTrigger` changes.
/// `kind` is 1–3 for minions; set `isBoss` for the island bosses (1–8).
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
    @State private var moodIndex = 0
    @State private var outfitIndex = 1
    @State private var gaitIndex = 0

    private var mood: AlpanicaMood { AlpanicaMood.allCases[moodIndex] }
    private var outfitItems: [ShopItem] { ShopCatalog.items(in: .outfit) }
    private var outfit: AlpanicaOutfit { AlpanicaOutfit(item: outfitItems[outfitIndex % outfitItems.count]) }

    var body: some View {
        VStack(spacing: 30) {
            HStack(alignment: .bottom, spacing: 60) {
                AlpanicaView(mood: mood, outfit: outfit, hopTrigger: hops, fidgets: true,
                             gait: AlpanicaGait.allCases[gaitIndex])
                FalsView(kind: 1, hitTrigger: hits)
                FalsView(kind: 6, isBoss: true, hitTrigger: hits, height: 300)
            }
            HStack(spacing: 20) {
                Button("Mood: \(String(describing: mood))") { moodIndex = (moodIndex + 1) % AlpanicaMood.allCases.count }
                Button("Outfit: \(outfit.id)") { outfitIndex = (outfitIndex + 1) % outfitItems.count }
                Button("Gait: \(String(describing: AlpanicaGait.allCases[gaitIndex]))") {
                    gaitIndex = (gaitIndex + 1) % AlpanicaGait.allCases.count
                }
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
