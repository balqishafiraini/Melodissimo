//
//  ChartRecorderViewModel.swift
//  Melodissimo
//

import Foundation
import Combine
import QuartzCore

/// The state of the DEBUG Chart Recorder: the player plays a song along with a metronome and each
/// correct key is recorded with its time. Like the other game logic, every time-based method takes
/// `now` (a `CACurrentMediaTime()` value) so tests can drive it.
final class ChartRecorderViewModel: ObservableObject {

    enum Phase: Hashable {
        case setup
        case recording
        case finished
    }

    /// Beats of metronome before the song starts.
    static let countInBeats = 4

    @Published private(set) var phase: Phase = .setup
    @Published var song: Song
    @Published var bpm = 90.0
    /// Grid in beats: 0.5 or 0.25.
    @Published var grid = 0.5
    /// How many notes are recorded so far.
    @Published private(set) var recordedCount = 0
    /// A wrong key, flashed red for a moment.
    @Published private(set) var wrongKeyId: Int?
    @Published private(set) var chart: SongChart?

    private(set) var presses: [RecordedPress] = []
    private var startTime: CFTimeInterval = 0

    init(song: Song) {
        self.song = song
    }

    var secondsPerBeat: Double { 60 / bpm }

    /// The key id the player should play next, or `nil` once the whole song is recorded.
    var expectedKeyId: Int? {
        song.keyIds.indices.contains(recordedCount) ? song.keyIds[recordedCount] : nil
    }

    /// The beat the metronome is on, counted from the first count-in beat (0-based). Negative before `start`.
    func metronomeBeat(now: CFTimeInterval) -> Int {
        guard phase == .recording else { return 0 }
        return Int(((now - startTime) / secondsPerBeat).rounded(.down))
    }

    /// Whether the count-in is still running (presses are ignored until it ends).
    func isCountingIn(now: CFTimeInterval) -> Bool {
        phase == .recording && metronomeBeat(now: now) < Self.countInBeats
    }

    /// 0…1 through the current beat, for the flashing dot.
    func beatProgress(now: CFTimeInterval) -> Double {
        guard phase == .recording else { return 0 }
        let beats = (now - startTime) / secondsPerBeat
        return beats - beats.rounded(.down)
    }

    func start(now: CFTimeInterval) {
        presses = []
        recordedCount = 0
        wrongKeyId = nil
        chart = nil
        startTime = now
        phase = .recording
    }

    /// A key went down. The right key is recorded; a wrong one flashes red and is ignored.
    func keyDown(_ keyId: Int, now: CFTimeInterval) {
        guard phase == .recording, !isCountingIn(now: now), let expected = expectedKeyId else { return }
        if keyId == expected {
            presses.append(RecordedPress(time: now, keyId: keyId))
            recordedCount += 1
            if expectedKeyId == nil { stop() }          // the last note: nothing left to record
        } else {
            wrongKeyId = keyId
        }
    }

    func clearWrongKey() {
        wrongKeyId = nil
    }

    /// Ends the recording and quantizes what was played into a chart.
    func stop() {
        guard phase == .recording else { return }
        let notes = ChartQuantizer.quantize(presses, bpm: bpm, grid: grid)
        chart = notes.isEmpty ? nil : ChartQuantizer.chart(for: song, bpm: bpm, notes: notes)
        phase = .finished
    }

    func reset() {
        presses = []
        recordedCount = 0
        wrongKeyId = nil
        chart = nil
        phase = .setup
    }
}
