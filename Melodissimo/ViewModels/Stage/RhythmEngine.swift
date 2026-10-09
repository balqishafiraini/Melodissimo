//
//  RhythmEngine.swift
//  Melodissimo
//

import Foundation
import Combine
import QuartzCore

/// A note on the highway, with its judgment once it has been hit or missed.
struct EngineNote: Hashable {
    let index: Int
    let keyId: Int
    /// Seconds on the song clock.
    let time: Double
    let duration: Double
    var judgment: Judgment?
}

/// A judged press or an auto-miss, kept briefly so the highway can draw a popup.
struct JudgmentEvent: Hashable {
    let keyId: Int
    /// `nil` is a wrong press: no note with that key was inside the timing window.
    let judgment: Judgment?
    let hostTime: CFTimeInterval
}

/// Runs one song stage: the song clock, judging, scoring and the practice / listen
/// behaviours. It has no UI and never reads the host clock itself — every time-based
/// method takes `now` (a `CACurrentMediaTime()` value) so tests can drive it with fake times.
///
/// Only things that matter to the HUD are `@Published`, and only when they actually
/// change. The song time and the note list are read directly, every frame, by the
/// highway's `Canvas`.
final class RhythmEngine: ObservableObject {

    enum Phase: Hashable {
        case ready, countIn, playing, paused, finished
    }

    /// The song clock starts this many beats before the first note, so the countdown is just `songTime < 0`.
    static let countInBeats = 3.0
    static let maxRecentEvents = 8
    /// Practice shows the right key after this many seconds of waiting…
    static let practiceHintDelay = 3.0
    /// …or after this many wrong presses on the same note.
    static let practiceHintWrongPresses = 2

    let chart: SongChart
    let mode: StageMode
    let speed: Double
    /// Seconds a note takes to fall from the top of the highway to the hit line.
    let approachTime: Double
    let audioOffsetMs: Int
    let countInDuration: Double

    @Published private(set) var phase: Phase = .ready
    @Published private(set) var score = 0
    @Published private(set) var combo = 0
    @Published private(set) var maxCombo = 0
    @Published private(set) var counts = JudgmentCounts()
    @Published private(set) var wrongPresses = 0
    /// Key to highlight: the right key in Practice after a struggle, the sounding key in Listen.
    @Published private(set) var hintKeyId: Int?

    private(set) var notes: [EngineNote]
    private(set) var recentEvents: [JudgmentEvent] = []
    /// Practice only: the song is frozen at the hit line, waiting for the right key.
    private(set) var isWaiting = false

    private var clock = PausableClock()
    private var firstUnjudged = 0
    private var waitStartedAt: CFTimeInterval = 0
    private var wrongPressesOnCurrentNote = 0
    private var listenActiveIndex: Int?
    private var ticker: DisplayLinkTicker?

    private let soundPlayer: (String) -> Void
    private let soundStopper: (String) -> Void

    init(chart: SongChart,
         mode: StageMode,
         speed: Double = 1,
         approachTime: Double = 2.0,
         audioOffsetMs: Int = 0,
         soundPlayer: @escaping (String) -> Void = { playSound(key: $0) },
         soundStopper: @escaping (String) -> Void = { stopSound(key: $0) }) {
        self.chart = chart
        self.mode = mode
        self.speed = speed
        self.approachTime = approachTime
        self.audioOffsetMs = audioOffsetMs
        self.soundPlayer = soundPlayer
        self.soundStopper = soundStopper
        self.countInDuration = Self.countInBeats * 60 / (chart.bpm * speed)
        self.notes = chart.timedNotes(speed: speed).map {
            EngineNote(index: $0.index, keyId: $0.keyId, time: $0.time, duration: $0.duration, judgment: nil)
        }
        clock.freeze(at: -countInDuration)
    }

    deinit {
        ticker?.stop()
    }

    // MARK: Derived values

    var totalNotes: Int { notes.count }

    /// Notes that have been hit or missed so far (for the HUD progress bar).
    var judgedCount: Int { notes.reduce(0) { $0 + ($1.judgment == nil ? 0 : 1) } }

    var comboMultiplier: Int { Judge.multiplier(forCombo: combo) }

    var accuracy: Double {
        Judge.accuracy(counts: counts, wrongPresses: wrongPresses, totalNotes: totalNotes)
    }

    /// No misses and no wrong presses.
    var isFullCombo: Bool { counts.miss == 0 && wrongPresses == 0 }

    /// Stars for the accuracy, optionally limited by the playback speed (1★ at 0.5×, 2★ at 0.75×).
    func stars(speedCapped: Bool = true) -> Int {
        let earned = Judge.stars(forAccuracy: accuracy)
        return speedCapped ? min(earned, Judge.starCap(forSpeed: speed)) : earned
    }

    /// Seconds on the song clock. Negative during the count-in.
    func songTime(now: CFTimeInterval) -> Double {
        clock.time(at: now)
    }

    /// The time presses are judged against: the song time shifted by the audio-latency setting.
    private func inputTime(now: CFTimeInterval) -> Double {
        songTime(now: now) - Double(audioOffsetMs) / 1000
    }

    // MARK: Lifecycle

    /// Begins the count-in. Does nothing unless the engine is `.ready`.
    func start(now: CFTimeInterval) {
        guard phase == .ready else { return }
        clock.start(at: now, from: -countInDuration)
        phase = .countIn
    }

    func pause(now: CFTimeInterval) {
        guard phase == .countIn || phase == .playing else { return }
        clock.pause(at: now)
        stopListenSound()
        phase = .paused
    }

    func resume(now: CFTimeInterval) {
        guard phase == .paused else { return }
        if isWaiting {
            // Still frozen at the hit line; don't hint the moment the player comes back.
            waitStartedAt = now
        } else {
            clock.resume(at: now)
        }
        phase = songTime(now: now) < 0 ? .countIn : .playing
    }

    /// Resets everything and begins a fresh count-in.
    func restart(now: CFTimeInterval) {
        stopListenSound()
        notes = notes.map { EngineNote(index: $0.index, keyId: $0.keyId, time: $0.time, duration: $0.duration, judgment: nil) }
        recentEvents = []
        firstUnjudged = 0
        isWaiting = false
        wrongPressesOnCurrentNote = 0
        listenActiveIndex = nil
        score = 0
        combo = 0
        maxCombo = 0
        counts = JudgmentCounts()
        wrongPresses = 0
        hintKeyId = nil
        clock = PausableClock()
        clock.freeze(at: -countInDuration)
        phase = .ready
        start(now: now)
    }

    // MARK: Input

    /// A key went down (a touch began or slid onto the key).
    func press(keyId: Int, now: CFTimeInterval) {
        guard phase == .countIn || phase == .playing else { return }
        // A press can land between frames, so don't rely on `step` having left the count-in yet.
        if phase == .countIn, songTime(now: now) >= 0 {
            phase = .playing
        }
        switch mode {
        case .perform: pressPerform(keyId: keyId, now: now)
        case .practice: pressPractice(keyId: keyId, now: now)
        case .listen: break
        }
    }

    private func pressPerform(keyId: Int, now: CFTimeInterval) {
        let t = inputTime(now: now)
        // Notes are sorted by time, so stop at the first one that hasn't entered the window yet.
        var i = firstUnjudged
        while i < notes.count, notes[i].time - t <= Judge.good {
            let note = notes[i]
            if note.judgment == nil, note.keyId == keyId, let judgment = Judge.judge(delta: t - note.time) {
                registerHit(at: i, judgment: judgment, now: now)
                return
            }
            i += 1
        }
        // A stray press during the count-in isn't held against the player.
        guard phase == .playing else { return }
        wrongPresses += 1
        combo = 0
        record(JudgmentEvent(keyId: keyId, judgment: nil, hostTime: now))
    }

    private func registerHit(at index: Int, judgment: Judgment, now: CFTimeInterval) {
        notes[index].judgment = judgment
        counts.add(judgment)
        combo += 1
        if combo > maxCombo { maxCombo = combo }
        score += Judge.points(for: judgment) * Judge.multiplier(forCombo: combo)
        record(JudgmentEvent(keyId: notes[index].keyId, judgment: judgment, hostTime: now))
        advanceFirstUnjudged()
        finishIfDone(now: now)
    }

    private func pressPractice(keyId: Int, now: CFTimeInterval) {
        guard firstUnjudged < notes.count else { return }
        let note = notes[firstUnjudged]
        // Only presses aimed at the next note count; an early correct press is fine.
        guard note.time - songTime(now: now) <= Judge.good else { return }

        if keyId == note.keyId {
            notes[firstUnjudged].judgment = .perfect
            record(JudgmentEvent(keyId: keyId, judgment: .perfect, hostTime: now))
            wrongPressesOnCurrentNote = 0
            if hintKeyId != nil { hintKeyId = nil }
            if isWaiting {
                isWaiting = false
                clock.resume(at: now)
            }
            advanceFirstUnjudged()
            finishIfDone(now: now)
        } else {
            wrongPresses += 1
            wrongPressesOnCurrentNote += 1
            record(JudgmentEvent(keyId: keyId, judgment: nil, hostTime: now))
            if wrongPressesOnCurrentNote >= Self.practiceHintWrongPresses, hintKeyId != note.keyId {
                hintKeyId = note.keyId
            }
        }
    }

    // MARK: Frame step

    /// Advances the engine to `now`: count-in → playing, auto-misses, practice wait,
    /// listen autoplay and finish detection. Called every frame by the display link.
    func step(now: CFTimeInterval) {
        guard phase == .countIn || phase == .playing else { return }
        let t = songTime(now: now)
        if phase == .countIn, t >= 0 {
            phase = .playing
        }
        switch mode {
        case .perform: stepPerform(now: now)
        case .practice: stepPractice(now: now, t: t)
        case .listen: stepListen(now: now, t: t)
        }
    }

    private func stepPerform(now: CFTimeInterval) {
        let t = inputTime(now: now)
        var missed = false
        var i = firstUnjudged
        while i < notes.count {
            if notes[i].judgment != nil { i += 1; continue }
            guard t - notes[i].time > Judge.good else { break }   // sorted: nothing later has expired either
            notes[i].judgment = .miss
            counts.add(.miss)
            record(JudgmentEvent(keyId: notes[i].keyId, judgment: .miss, hostTime: now))
            missed = true
            i += 1
        }
        if missed {
            combo = 0
            advanceFirstUnjudged()
        }
        finishIfDone(now: now)
    }

    private func stepPractice(now: CFTimeInterval, t: Double) {
        guard firstUnjudged < notes.count else {
            finishIfDone(now: now)
            return
        }
        let note = notes[firstUnjudged]
        if !isWaiting {
            if t >= note.time {
                clock.freeze(at: note.time)
                isWaiting = true
                waitStartedAt = now
                wrongPressesOnCurrentNote = 0
            }
        } else if hintKeyId == nil, now - waitStartedAt >= Self.practiceHintDelay {
            hintKeyId = note.keyId
        }
    }

    private func stepListen(now: CFTimeInterval, t: Double) {
        if let active = listenActiveIndex, t >= hintEnd(of: notes[active]) {
            stopListenSound()
        }
        // Play the most recent note that is due; if a long gap skipped some, they are silently marked.
        var due: Int?
        while firstUnjudged < notes.count, notes[firstUnjudged].time <= t {
            notes[firstUnjudged].judgment = .perfect
            due = firstUnjudged
            firstUnjudged += 1
        }
        if let due {
            stopListenSound()
            let note = notes[due]
            soundPlayer(NoteCatalog.note(note.keyId).sound)
            listenActiveIndex = due
            hintKeyId = note.keyId
        }
        if let last = notes.last, t >= last.time + last.duration {
            stopListenSound()
            finish(now: now)
        } else if notes.isEmpty {
            finish(now: now)
        }
    }

    /// The hint ends a little before the note does, so repeated notes visibly retrigger.
    private func hintEnd(of note: EngineNote) -> Double {
        note.time + max(note.duration - min(0.08, note.duration * 0.25), note.duration * 0.5)
    }

    private func stopListenSound() {
        guard let active = listenActiveIndex else { return }
        soundStopper(NoteCatalog.note(notes[active].keyId).sound)
        listenActiveIndex = nil
        if hintKeyId != nil { hintKeyId = nil }
    }

    // MARK: Helpers

    private func record(_ event: JudgmentEvent) {
        recentEvents.append(event)
        if recentEvents.count > Self.maxRecentEvents {
            recentEvents.removeFirst(recentEvents.count - Self.maxRecentEvents)
        }
    }

    private func advanceFirstUnjudged() {
        while firstUnjudged < notes.count, notes[firstUnjudged].judgment != nil {
            firstUnjudged += 1
        }
    }

    /// Perform and Practice finish when every note has been judged.
    private func finishIfDone(now: CFTimeInterval) {
        guard mode != .listen, firstUnjudged >= notes.count else { return }
        finish(now: now)
    }

    private func finish(now: CFTimeInterval) {
        guard phase != .finished else { return }
        clock.pause(at: now)
        isWaiting = false
        if hintKeyId != nil { hintKeyId = nil }
        phase = .finished
    }

    // MARK: Display link

    /// Starts calling `step(now:)` every frame. Pair with `detachTicker()` in `onDisappear`.
    func attachTicker() {
        guard ticker == nil else { return }
        let newTicker = DisplayLinkTicker { [weak self] now in self?.step(now: now) }
        ticker = newTicker
        newTicker.start()
    }

    func detachTicker() {
        ticker?.stop()
        ticker = nil
    }
}

// MARK: - Display link

/// Calls `onTick` with the frame timestamp (a `CACurrentMediaTime()`-based value) on every
/// screen refresh. `CADisplayLink` retains its target, so the link points at a weak proxy
/// instead of this object; call `stop()` (or just drop the ticker) when done.
final class DisplayLinkTicker {
    private var link: CADisplayLink?
    private let onTick: (CFTimeInterval) -> Void

    init(onTick: @escaping (CFTimeInterval) -> Void) {
        self.onTick = onTick
    }

    deinit {
        link?.invalidate()
    }

    func start() {
        guard link == nil else { return }
        let proxy = TickerProxy(ticker: self)
        let newLink = CADisplayLink(target: proxy, selector: #selector(TickerProxy.tick(_:)))
        newLink.add(to: .main, forMode: .common)
        link = newLink
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    fileprivate func fire(_ link: CADisplayLink) {
        onTick(link.timestamp)
    }
}

private final class TickerProxy: NSObject {
    private weak var ticker: DisplayLinkTicker?

    init(ticker: DisplayLinkTicker) {
        self.ticker = ticker
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let ticker else {
            link.invalidate()
            return
        }
        ticker.fire(link)
    }
}
