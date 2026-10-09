//
//  HighwayGeometry.swift
//  Melodissimo
//

import Foundation

/// The layout math of the note highway, kept free of drawing code so it can be tested.
///
/// A note's bottom edge is at the hit line when `songTime == note.time` and at the top of the
/// highway `approachTime` seconds earlier; the note extends upward from its bottom edge.
enum HighwayGeometry {

    /// How long a note is allowed to be shorter than: one tap target.
    static let minimumNoteLength: CGFloat = 24
    /// A note is drawn a bit shorter than its duration so consecutive notes show a gap.
    static let lengthFactor: CGFloat = 0.9
    /// Seconds past the hit line that a note stays visible while it falls out of view.
    static let exitWindow = 0.3

    /// y of the note's bottom edge: `hitY − (time − t) / approachTime × hitY`.
    static func bottomY(noteTime: Double, songTime: Double, approachTime: Double, hitY: CGFloat) -> CGFloat {
        hitY - CGFloat((noteTime - songTime) / approachTime) * hitY
    }

    /// Height of a note: `max(24, duration / approachTime × hitY × 0.9)`.
    static func length(duration: Double, approachTime: Double, hitY: CGFloat) -> CGFloat {
        max(minimumNoteLength, CGFloat(duration / approachTime) * hitY * lengthFactor)
    }

    /// Whether a note could be on screen: it has entered at the top and hasn't fully left past the hit line.
    static func isVisible(noteTime: Double, duration: Double, songTime: Double, approachTime: Double) -> Bool {
        noteTime <= songTime + approachTime && noteTime + duration >= songTime - exitWindow
    }

    /// The rectangle of a note in highway coordinates, inset a little so neighbouring lanes don't touch.
    static func noteRect(noteTime: Double, duration: Double, songTime: Double, approachTime: Double,
                         hitY: CGFloat, keyFrame: CGRect, highwayOriginX: CGFloat, inset: CGFloat = 3) -> CGRect {
        let bottom = bottomY(noteTime: noteTime, songTime: songTime, approachTime: approachTime, hitY: hitY)
        let height = length(duration: duration, approachTime: approachTime, hitY: hitY)
        return CGRect(x: keyFrame.minX - highwayOriginX + inset,
                      y: bottom - height,
                      width: max(0, keyFrame.width - inset * 2),
                      height: height)
    }
}

/// The 3-2-1 shown while the song clock is still negative.
enum CountIn {
    /// Which number to show and how far into its beat the clock is (0 at the start, 1 at the end).
    /// `nil` once the song has started.
    static func display(songTime: Double, secondsPerBeat: Double, beats: Int = 3) -> (number: Int, progress: Double)? {
        guard songTime < 0, secondsPerBeat > 0 else { return nil }
        let remaining = min(Double(beats), -songTime / secondsPerBeat)        // beats left, beats...0
        let number = min(beats, max(1, Int(remaining.rounded(.up))))
        let progress = min(1, max(0, Double(number) - remaining))
        return (number, progress)
    }
}
