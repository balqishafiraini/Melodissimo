//
//  NoteHighwayView.swift
//  Melodissimo
//

import SwiftUI

/// The falling notes of a song stage. Everything is drawn in a single `Canvas` that is
/// redrawn every frame from the engine's song clock: there is never one SwiftUI view per note.
///
/// Notes fall in lanes lined up with the keyboard keys (`keyFrames` are the keys' frames in the
/// window's coordinate space) and reach the hit line just above the keyboard. Notes are never
/// erased on a hit: they keep falling past the hit line until they leave on their own, sparkling as they slide
/// through it. Missed notes turn grey.
struct NoteHighwayView: View {
    let engine: RhythmEngine
    /// Key id → frame in window coordinates, reported by `PianoKeyboard`.
    let keyFrames: [Int: CGRect]
    var labelsOnNotes = true
    /// Rising "Perfect!" / "Great" / "Good" / "Miss" popups. Only Perform mode judges, so other modes never show them.
    var showsPopups = true
    /// Solemn songs show a quiet check mark for a hit instead of judgment words, and nothing for a miss.
    var isSolemn = false
    /// When each key was last pressed, for the lane flash. `nil` draws no flash.
    var laneFlashes: LaneFlashes?
    /// Reduce Motion: no particles, only fades.
    var reduceMotion = false

    /// The equipped falling-note skin, read once when the stage opens.
    private let noteSkin = NoteSkin.equipped

    /// The keys this song actually uses. Only their labels are built as canvas symbols: the symbols are
    /// rebuilt every frame, and a song uses 8 to 15 of the 32 keys.
    private let usedKeyIds: [Int]

    /// One note with everything about it that never changes during a play, worked out once. `index` is the note's
    /// place in `engine.notes`, where its judgment is read each frame.
    fileprivate struct RenderNote {
        let index: Int
        let keyId: Int
        let time: Double
        let duration: Double
        let fill: Color
    }

    /// White-key and black-key notes, each sorted by time, so a frame can binary-search the few that are on screen
    /// instead of looping over the whole song twice.
    private let whiteNotes: [RenderNote]
    private let blackNotes: [RenderNote]
    /// The longest note's duration: a note that started this long before now may still be on screen.
    private let longestNote: Double
    /// The lane lines, built once per set of key frames rather than every frame.
    private let laneCache = LanePathCache()

    init(engine: RhythmEngine, keyFrames: [Int: CGRect], labelsOnNotes: Bool = true, showsPopups: Bool = true,
         isSolemn: Bool = false, laneFlashes: LaneFlashes? = nil, reduceMotion: Bool = false) {
        self.engine = engine
        self.keyFrames = keyFrames
        self.labelsOnNotes = labelsOnNotes
        self.showsPopups = showsPopups
        self.isSolemn = isSolemn
        self.laneFlashes = laneFlashes
        self.reduceMotion = reduceMotion
        self.usedKeyIds = Array(Set(engine.notes.map(\.keyId))).sorted()

        let skin = noteSkin
        var white: [RenderNote] = []
        var black: [RenderNote] = []
        for note in engine.notes {
            let key = NoteCatalog.note(note.keyId)
            let fill = skin.color(semitone: key.semitone, isBlack: key.isBlack) ?? (key.isBlack ? .navy : .yellow)
            let render = RenderNote(index: note.index, keyId: note.keyId, time: note.time, duration: note.duration, fill: fill)
            if key.isBlack { black.append(render) } else { white.append(render) }
        }
        self.whiteNotes = white.sorted { $0.time < $1.time }
        self.blackNotes = black.sorted { $0.time < $1.time }
        self.longestNote = engine.notes.map(\.duration).max() ?? 0
    }

    /// How long a judgment popup rises and fades.
    static let popupDuration = 0.5

    /// Space under the hit line, so the line itself isn't clipped by the bottom edge.
    private static let hitLineInset: CGFloat = Sizing.s(10)

    var body: some View {
        GeometryReader { geo in
            let originX = geo.frame(in: .global).minX
            TimelineView(.animation) { timeline in
                // The canvas closure must capture something that changes every frame (the timeline's
                // date), otherwise SwiftUI sees an unchanged closure and stops redrawing it.
                let frameDate = timeline.date
                Canvas { context, size in
                    draw(&context, size: size, originX: originX, frameDate: frameDate)
                } symbols: {
                    ForEach(usedKeyIds, id: \.self) { keyId in
                        let note = NoteCatalog.note(keyId)
                        Text(note.label)
                            .font(.custom("BalooDa-Regular", size: Sizing.f(22)))
                            .foregroundColor(note.isBlack ? .white : .darkGreen)
                            .tag(note.id)
                    }
                    ForEach(Judgment.allCases, id: \.self) { judgment in
                        Self.popupLabel(judgment)
                            .tag(Self.popupSymbolID(judgment))
                    }
                    Image(systemName: "checkmark")
                        .font(.custom("BalooDa-Regular", size: Sizing.f(26)))
                        .foregroundColor(.white)
                        .tag(Self.solemnCheckID)
                }
            }
        }
    }

    // MARK: Popups

    private static let solemnCheckID = "solemn-check"

    private static func popupSymbolID(_ judgment: Judgment) -> String {
        "judgment-\(judgment.rawValue)"
    }

    /// The popup's text and colour: both, so the judgment never depends on colour alone.
    private static func popupLabel(_ judgment: Judgment) -> some View {
        let (text, color): (LocalizedStringKey, Color) = {
            switch judgment {
            case .perfect: return ("Perfect!", .yellow)
            case .great: return ("Great", .softGreen)
            case .good: return ("Good", .softBlue)
            case .miss: return ("Miss", .red)
            }
        }()
        return Text(text)
            .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
            .foregroundColor(color)
            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, size: CGSize, originX: CGFloat, frameDate: Date) {
        _ = frameDate   // only here to make every frame's closure differ; timing uses the host clock
        let songTime = engine.songTime(now: CACurrentMediaTime())
        let hitY = size.height - Self.hitLineInset

        drawLanes(&context, size: size, originX: originX)
        drawLaneFlashes(&context, hitY: hitY, originX: originX)
        drawHitLine(&context, size: size, hitY: hitY)

        // White-key notes first so the narrower black-key notes sit on top of them. Each list is sorted by time:
        // start at the first note that could still be on screen and stop at the first one not yet in.
        let earliest = songTime - longestNote - HighwayGeometry.exitWindow
        let latest = songTime + engine.approachTime
        var sparkling: [(rect: CGRect, index: Int)] = []
        for notes in [whiteNotes, blackNotes] {
            var i = Self.firstIndex(in: notes, timeAtLeast: earliest)
            while i < notes.count, notes[i].time <= latest {
                if let rect = drawNote(notes[i], &context, songTime: songTime, hitY: hitY, originX: originX) {
                    sparkling.append((rect, notes[i].index))
                }
                i += 1
            }
        }
        drawSparkles(&context, notes: sparkling, hitY: hitY, songTime: songTime)

        if showsPopups {
            drawBursts(&context, hitY: hitY, originX: originX)
            drawPopups(&context, hitY: hitY, originX: originX)
        }
    }

    /// A key-down lights its lane from the hit line upward and fades over `LaneFlashes.duration`.
    /// Solemn songs stay calm, so they pass no `laneFlashes`.
    private func drawLaneFlashes(_ context: inout GraphicsContext, hitY: CGFloat, originX: CGFloat) {
        guard let laneFlashes else { return }
        for flash in laneFlashes.active(at: CACurrentMediaTime()) {
            guard let keyFrame = keyFrames[flash.keyId] else { continue }
            let rect = CGRect(x: keyFrame.minX - originX, y: 0, width: keyFrame.width, height: hitY)
            var layer = context
            layer.opacity = 0.28 * (1 - flash.progress)
            layer.fill(Path(rect), with: .color(.white))
        }
    }

    /// Small circles fanning out of the hit line on a Perfect. None for solemn songs or with Reduce Motion.
    private func drawBursts(_ context: inout GraphicsContext, hitY: CGFloat, originX: CGFloat) {
        guard !isSolemn, !reduceMotion else { return }
        let now = CACurrentMediaTime()
        for event in engine.recentEvents where event.judgment == .perfect {
            let age = now - event.hostTime
            guard age >= 0, age < HitBurst.duration, let keyFrame = keyFrames[event.keyId] else { continue }
            let centre = CGPoint(x: keyFrame.midX - originX, y: hitY)
            let seed = event.keyId &+ Int(event.hostTime * 1000)
            for (index, particle) in HitBurst.particles(progress: age / HitBurst.duration, seed: seed).enumerated() {
                var layer = context
                layer.opacity = particle.opacity
                let dot = CGRect(x: centre.x + particle.dx - particle.radius, y: centre.y + particle.dy - particle.radius,
                                 width: particle.radius * 2, height: particle.radius * 2)
                layer.fill(Path(ellipseIn: dot), with: .color(index.isMultiple(of: 2) ? Color.yellow : .white))
            }
        }
    }

    /// Each recent judgment rises from the hit line at its lane and fades out over `popupDuration`.
    private func drawPopups(_ context: inout GraphicsContext, hitY: CGFloat, originX: CGFloat) {
        let now = CACurrentMediaTime()
        for event in engine.recentEvents {
            // A wrong press has no popup: the key flash and the lost combo say enough.
            guard let judgment = event.judgment else { continue }
            // Solemn songs only get a faint check mark for hits.
            if isSolemn, judgment == .miss { continue }
            let age = now - event.hostTime
            let symbolID = isSolemn ? Self.solemnCheckID : Self.popupSymbolID(judgment)
            guard age >= 0, age < Self.popupDuration,
                  let keyFrame = keyFrames[event.keyId],
                  let symbol = context.resolveSymbol(id: symbolID) else { continue }
            let progress = CGFloat(age / Self.popupDuration)
            var layer = context
            layer.opacity = Double(1 - progress) * (isSolemn ? 0.5 : 1)
            layer.draw(symbol, at: CGPoint(x: keyFrame.midX - originX, y: hitY - Sizing.s(40) - Sizing.s(50) * progress))
        }
    }

    private func drawLanes(_ context: inout GraphicsContext, size: CGSize, originX: CGFloat) {
        let path = laneCache.path(originX: originX, height: size.height) {
            var path = Path()
            for id in NoteCatalog.whiteKeyIDs {
                guard let frame = keyFrames[id] else { continue }
                let x = frame.minX - originX
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            if let last = keyFrames[NoteCatalog.whiteKeyIDs.last ?? 0] {
                let x = last.maxX - originX
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            return path
        }
        context.stroke(path, with: .color(Color.white.opacity(0.12)), lineWidth: 1)
    }

    private func drawHitLine(_ context: inout GraphicsContext, size: CGSize, hitY: CGFloat) {
        let glow: CGFloat = Sizing.isPhone ? 8 : 14
        context.fill(Path(CGRect(x: 0, y: hitY - glow / 2, width: size.width, height: glow)), with: .color(Color.yellow.opacity(0.22)))
        context.fill(Path(CGRect(x: 0, y: hitY - 2, width: size.width, height: 4)), with: .color(Color.white.opacity(0.9)))
    }

    /// Draws one note. Returns its rectangle when it is a hit note sliding through the hit line, so it can sparkle there.
    private func drawNote(_ note: RenderNote, _ context: inout GraphicsContext, songTime: Double, hitY: CGFloat,
                          originX: CGFloat) -> CGRect? {
        // Every note keeps falling until it leaves the highway; missed ones turn grey.
        let judgment = engine.notes[note.index].judgment
        guard HighwayGeometry.isVisible(noteTime: note.time, duration: note.duration,
                                        songTime: songTime, approachTime: engine.approachTime),
              let keyFrame = keyFrames[note.keyId] else { return nil }

        let rect = HighwayGeometry.noteRect(noteTime: note.time, duration: note.duration,
                                            songTime: songTime, approachTime: engine.approachTime,
                                            hitY: hitY, keyFrame: keyFrame, highwayOriginX: originX,
                                            minimumLength: Sizing.s(HighwayGeometry.minimumNoteLength))
        let fill: Color = judgment == .miss ? Color.gray.opacity(0.55) : note.fill
        let shape = Path(roundedRect: rect, cornerRadius: Sizing.s(10))
        context.fill(shape, with: .color(fill))
        context.stroke(shape, with: .color(Color.white.opacity(0.85)), lineWidth: 2)

        if labelsOnNotes, let label = context.resolveSymbol(id: note.keyId) {
            context.draw(label, at: CGPoint(x: rect.midX, y: max(rect.minY + Sizing.s(14), rect.maxY - Sizing.s(20))))
        }
        guard let judgment, judgment != .miss, rect.minY < hitY, rect.maxY >= hitY else { return nil }
        return rect
    }

    /// A hit note glows white where it slides through the hit line and throws off twinkles, so it reads as being
    /// played. Solemn songs and Reduce Motion keep only a softer, still glow.
    private func drawSparkles(_ context: inout GraphicsContext, notes: [(rect: CGRect, index: Int)], hitY: CGFloat,
                              songTime: Double) {
        let calm = isSolemn || reduceMotion
        for (rect, index) in notes {
            let centre = CGPoint(x: rect.midX, y: hitY)
            // At least a little wider than the lane, so it still reads on a phone's narrow keys.
            let radius = max(rect.width * 1.1, Sizing.s(40))
            let glow = CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: glow),
                         with: .radialGradient(Gradient(colors: [.white.opacity(calm ? 0.45 : 0.9), .white.opacity(0)]),
                                               center: centre, startRadius: 0, endRadius: radius))
            let core = CGRect(x: rect.minX + 2, y: hitY - Sizing.s(4), width: rect.width - 4, height: Sizing.s(8))
            context.fill(Path(roundedRect: core, cornerRadius: Sizing.s(4)), with: .color(.white.opacity(calm ? 0.6 : 0.95)))
            guard !calm else { continue }
            for (n, twinkle) in HitSparkle.twinkles(time: songTime, seed: index).enumerated() {
                let star = CGPoint(x: centre.x + CGFloat(twinkle.dx) * radius * 1.3, y: hitY + Sizing.s(CGFloat(twinkle.dy)))
                var layer = context
                layer.opacity = twinkle.opacity
                layer.fill(Self.starPath(centre: star, radius: Sizing.s(CGFloat(twinkle.size))),
                           with: .color(n.isMultiple(of: 2) ? .white : .yellow))
            }
        }
    }

    /// A four-pointed star, the shape of a twinkle.
    private static func starPath(centre: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for point in 0..<8 {
            let angle = Double(point) * .pi / 4 - .pi / 2
            let reach = point.isMultiple(of: 2) ? radius : radius * 0.32
            let corner = CGPoint(x: centre.x + CGFloat(cos(angle)) * reach, y: centre.y + CGFloat(sin(angle)) * reach)
            if point == 0 { path.move(to: corner) } else { path.addLine(to: corner) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Per-frame helpers

extension NoteHighwayView {
    /// The first index whose note starts at `time` or later (the list is sorted by time).
    fileprivate static func firstIndex(in notes: [RenderNote], timeAtLeast time: Double) -> Int {
        var low = 0
        var high = notes.count
        while low < high {
            let mid = (low + high) / 2
            if notes[mid].time < time { low = mid + 1 } else { high = mid }
        }
        return low
    }
}

/// Holds the lane lines between frames. A reference type because the highway is a value and its `Canvas` closure
/// can't mutate it; the path only changes when the highway moves or resizes, which is rare.
private final class LanePathCache {
    private var originX: CGFloat?
    private var height: CGFloat?
    private var cached = Path()

    func path(originX: CGFloat, height: CGFloat, build: () -> Path) -> Path {
        if self.originX != originX || self.height != height {
            cached = build()
            self.originX = originX
            self.height = height
        }
        return cached
    }
}
