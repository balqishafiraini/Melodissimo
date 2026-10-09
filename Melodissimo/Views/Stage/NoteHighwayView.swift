//
//  NoteHighwayView.swift
//  Melodissimo
//

import SwiftUI

/// The falling notes of a song stage. Everything is drawn in a single `Canvas` that is
/// redrawn every frame from the engine's song clock: there is never one SwiftUI view per note.
///
/// Notes fall in lanes lined up with the keyboard keys (`keyFrames` are the keys' frames in the
/// window's coordinate space) and reach the hit line just above the keyboard. Hit notes vanish;
/// missed notes turn grey and keep falling.
struct NoteHighwayView: View {
    let engine: RhythmEngine
    /// Key id → frame in window coordinates, reported by `PianoKeyboard`.
    let keyFrames: [Int: CGRect]
    var labelsOnNotes = true
    /// Rising "Perfect!" / "Great" / "Good" / "Miss" popups. Only Perform mode judges, so other modes never show them.
    var showsPopups = true

    /// How long a judgment popup rises and fades.
    static let popupDuration = 0.5

    /// Space under the hit line, so the line itself isn't clipped by the bottom edge.
    private static let hitLineInset: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let originX = geo.frame(in: .global).minX
            TimelineView(.animation) { timeline in
                // Reading the date is what makes SwiftUI redraw the canvas on every frame.
                let _ = timeline.date
                Canvas { context, size in
                    draw(&context, size: size, originX: originX)
                } symbols: {
                    ForEach(NoteCatalog.all) { note in
                        Text(note.label)
                            .font(.custom("BalooDa-Regular", size: 22))
                            .foregroundColor(note.isBlack ? .white : .darkGreen)
                            .tag(note.id)
                    }
                    ForEach(Judgment.allCases, id: \.self) { judgment in
                        Self.popupLabel(judgment)
                            .tag(Self.popupSymbolID(judgment))
                    }
                }
            }
        }
    }

    // MARK: Popups

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
            .font(.custom("BalooDa-Regular", size: 28))
            .foregroundColor(color)
            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, size: CGSize, originX: CGFloat) {
        let songTime = engine.songTime(now: CACurrentMediaTime())
        let hitY = size.height - Self.hitLineInset

        drawLanes(&context, size: size, originX: originX)
        drawHitLine(&context, size: size, hitY: hitY)

        // White-key notes first so the narrower black-key notes sit on top of them.
        for blackKeys in [false, true] {
            for note in engine.notes where NoteCatalog.note(note.keyId).isBlack == blackKeys {
                drawNote(note, &context, songTime: songTime, hitY: hitY, originX: originX)
            }
        }

        if showsPopups {
            drawPopups(&context, hitY: hitY, originX: originX)
        }
    }

    /// Each recent judgment rises from the hit line at its lane and fades out over `popupDuration`.
    private func drawPopups(_ context: inout GraphicsContext, hitY: CGFloat, originX: CGFloat) {
        let now = CACurrentMediaTime()
        for event in engine.recentEvents {
            // A wrong press has no popup: the key flash and the lost combo say enough.
            guard let judgment = event.judgment else { continue }
            let age = now - event.hostTime
            guard age >= 0, age < Self.popupDuration,
                  let keyFrame = keyFrames[event.keyId],
                  let symbol = context.resolveSymbol(id: Self.popupSymbolID(judgment)) else { continue }
            let progress = CGFloat(age / Self.popupDuration)
            var layer = context
            layer.opacity = Double(1 - progress)
            layer.draw(symbol, at: CGPoint(x: keyFrame.midX - originX, y: hitY - 40 - 50 * progress))
        }
    }

    private func drawLanes(_ context: inout GraphicsContext, size: CGSize, originX: CGFloat) {
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
        context.stroke(path, with: .color(Color.white.opacity(0.12)), lineWidth: 1)
    }

    private func drawHitLine(_ context: inout GraphicsContext, size: CGSize, hitY: CGFloat) {
        context.fill(Path(CGRect(x: 0, y: hitY - 7, width: size.width, height: 14)), with: .color(Color.yellow.opacity(0.22)))
        context.fill(Path(CGRect(x: 0, y: hitY - 2, width: size.width, height: 4)), with: .color(Color.white.opacity(0.9)))
    }

    private func drawNote(_ note: EngineNote, _ context: inout GraphicsContext, songTime: Double, hitY: CGFloat, originX: CGFloat) {
        // Hit notes vanish; missed ones stay and turn grey.
        if let judgment = note.judgment, judgment != .miss { return }
        guard HighwayGeometry.isVisible(noteTime: note.time, duration: note.duration,
                                        songTime: songTime, approachTime: engine.approachTime),
              let keyFrame = keyFrames[note.keyId] else { return }

        let rect = HighwayGeometry.noteRect(noteTime: note.time, duration: note.duration,
                                            songTime: songTime, approachTime: engine.approachTime,
                                            hitY: hitY, keyFrame: keyFrame, highwayOriginX: originX)
        let isBlack = NoteCatalog.note(note.keyId).isBlack
        let fill: Color = note.judgment == .miss ? Color.gray.opacity(0.55) : (isBlack ? .navy : .yellow)
        let shape = Path(roundedRect: rect, cornerRadius: 10)
        context.fill(shape, with: .color(fill))
        context.stroke(shape, with: .color(Color.white.opacity(0.85)), lineWidth: 2)

        if labelsOnNotes, let label = context.resolveSymbol(id: note.keyId) {
            context.draw(label, at: CGPoint(x: rect.midX, y: max(rect.minY + 14, rect.maxY - 20)))
        }
    }
}
