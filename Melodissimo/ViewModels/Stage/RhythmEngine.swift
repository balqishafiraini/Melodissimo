//
//  RhythmEngine.swift
//  Melodissimo
//

import Foundation
import Combine
import QuartzCore

/// What became of a hit long note.
enum HoldState: Hashable {
    /// The key is still down; the note stays at the hit line and shrinks as its tail comes down.
    case holding
    /// Held to the tail.
    case completed
    /// Let go at this song time, before the tail.
    case broken(at: Double)
}

/// A note on the highway, with its judgment once it has been hit or missed.
struct EngineNote: Hashable {
    let index: Int
    let keyId: Int
    /// Seconds on the song clock.
    let time: Double
    let duration: Double
    /// A long note: hitting it starts a hold that lasts until `holdEnd`.
    var isHold = false
    var judgment: Judgment?
    /// Set once a hold note has been hit.
    var hold: HoldState?

    /// Song time of the tail as drawn (notes are drawn `lengthFactor` of their duration long).
    var holdEnd: Double {
        time + duration * Double(HighwayGeometry.lengthFactor)
    }
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
/// Only the phase and the hint key are `@Published` here. The numbers that change with every
/// judgment live on `scoreboard`, which only the HUD observes. The song time and the note list
/// are read directly, every frame, by the highway's `Canvas`.
final class RhythmEngine: ObservableObject {

    enum Phase: Hashable {
        case ready, countIn, playing, paused, finished
    }

    /// What the song clock is doing, for anything that must follow it (the backing track).
    enum ClockEvent: Equatable {
        /// Running: at host time `hostTime` the clock reads `songTime`.
        case running(songTime: Double, hostTime: CFTimeInterval)
        /// Stopped at `songTime` (pause, Practice wait, restart).
        case halted(songTime: Double)
        case finished
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
    /// Seconds added to every judgment window (the microphone mode's allowance for detection delay).
    let windowBonus: Double
    let countInDuration: Double
    /// Seconds the clock runs before beat 0: the count-in, or longer when a backing track has an intro.
    let leadInDuration: Double

    @Published private(set) var phase: Phase = .ready
    /// Score, combo, counts and the wrong-press flash, observed by the HUD views only.
    let scoreboard = StageScoreboard()
    /// Key to highlight: the right key in Practice after a struggle, the sounding key in Listen.
    @Published private(set) var hintKeyId: Int?

    private(set) var notes: [EngineNote]
    private(set) var recentEvents: [JudgmentEvent] = []
    /// Practice only: the song is frozen at the hit line, waiting for the right key.
    private(set) var isWaiting = false
    /// Called whenever the song clock starts, halts, resumes or ends.
    var onClockEvent: ((ClockEvent) -> Void)?
    /// Called synchronously for every judged press or auto-miss, at the moment it happens: the judgment, or `nil` for a
    /// wrong press. The stage plays its sound effects from it. The closure lives as long as the engine, so it must
    /// capture plain values only, never the engine, the scoreboard or a view.
    var onJudgment: ((Judgment?) -> Void)?

    private var clock = PausableClock()
    private var firstUnjudged = 0
    private var waitStartedAt: CFTimeInterval = 0
    private var wrongPressesOnCurrentNote = 0
    private var listenActiveIndex: Int?
    /// Key id → index of the hold note that key is holding down.
    private var holding: [Int: Int] = [:]
    private var ticker: DisplayLinkTicker?

    private let soundPlayer: (String) -> Void
    private let soundStopper: (String) -> Void

    init(chart: SongChart,
         mode: StageMode,
         speed: Double = 1,
         approachTime: Double = 2.0,
         audioOffsetMs: Int = 0,
         windowBonus: Double = 0,
         leadIn: Double = 0,
         soundPlayer: @escaping (String) -> Void = { playSound(key: $0) },
         soundStopper: @escaping (String) -> Void = { stopSound(key: $0) }) {
        self.chart = chart
        self.mode = mode
        self.speed = speed
        self.approachTime = approachTime
        self.audioOffsetMs = audioOffsetMs
        self.windowBonus = windowBonus
        self.soundPlayer = soundPlayer
        self.soundStopper = soundStopper
        self.countInDuration = Self.countInBeats * 60 / (chart.bpm * speed)
        self.leadInDuration = max(countInDuration, leadIn)
        self.notes = chart.timedNotes(speed: speed).map {
            EngineNote(index: $0.index, keyId: $0.keyId, time: $0.time, duration: $0.duration, isHold: $0.isHold)
        }
        clock.freeze(at: -leadInDuration)
    }

    deinit {
        ticker?.stop()
    }

    // MARK: Derived values

    var totalNotes: Int { notes.count }

    // Read-only views of the scoreboard, so tests and `finish()` read the numbers where they always were.
    var score: Int { scoreboard.score }
    var combo: Int { scoreboard.combo }
    var maxCombo: Int { scoreboard.maxCombo }
    var counts: JudgmentCounts { scoreboard.counts }
    var wrongPresses: Int { scoreboard.wrongPresses }
    /// Notes that have been hit or missed so far (for the HUD progress bar).
    var judgedCount: Int { scoreboard.judgedCount }

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
        clock.start(at: now, from: -leadInDuration)
        phase = .countIn
        onClockEvent?(.running(songTime: -leadInDuration, hostTime: now))
    }

    func pause(now: CFTimeInterval) {
        guard phase == .countIn || phase == .playing else { return }
        clock.pause(at: now)
        stopListenSound()
        phase = .paused
        onClockEvent?(.halted(songTime: songTime(now: now)))
    }

    func resume(now: CFTimeInterval) {
        guard phase == .paused else { return }
        if isWaiting {
            // Still frozen at the hit line; don't hint the moment the player comes back.
            waitStartedAt = now
        } else {
            clock.resume(at: now)
            onClockEvent?(.running(songTime: songTime(now: now), hostTime: now))
        }
        phase = songTime(now: now) < 0 ? .countIn : .playing
    }

    /// Resets everything and begins a fresh count-in.
    func restart(now: CFTimeInterval) {
        stopListenSound()
        notes = notes.map { EngineNote(index: $0.index, keyId: $0.keyId, time: $0.time, duration: $0.duration, isHold: $0.isHold) }
        recentEvents = []
        holding = [:]
        firstUnjudged = 0
        isWaiting = false
        wrongPressesOnCurrentNote = 0
        listenActiveIndex = nil
        scoreboard.reset()
        hintKeyId = nil
        clock = PausableClock()
        clock.freeze(at: -leadInDuration)
        phase = .ready
        onClockEvent?(.halted(songTime: -leadInDuration))
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
        while i < notes.count, notes[i].time - t <= Judge.good + windowBonus {
            let note = notes[i]
            if note.judgment == nil, note.keyId == keyId, let judgment = Judge.judge(delta: t - note.time, bonus: windowBonus) {
                registerHit(at: i, judgment: judgment, now: now)
                return
            }
            i += 1
        }
        // A stray press during the count-in isn't held against the player.
        guard phase == .playing else { return }
        scoreboard.registerWrongPress(keyId: keyId, breaksCombo: true)
        record(JudgmentEvent(keyId: keyId, judgment: nil, hostTime: now))
        onJudgment?(nil)
    }

    private func registerHit(at index: Int, judgment: Judgment, now: CFTimeInterval) {
        notes[index].judgment = judgment
        // The multiplier is the one for the combo *including* this hit, as before.
        scoreboard.registerHit(judgment, points: Judge.points(for: judgment) * Judge.multiplier(forCombo: scoreboard.combo + 1))
        record(JudgmentEvent(keyId: notes[index].keyId, judgment: judgment, hostTime: now))
        onJudgment?(judgment)
        beginHold(at: index)
        advanceFirstUnjudged()
        finishIfDone(now: now)
    }

    private func pressPractice(keyId: Int, now: CFTimeInterval) {
        guard firstUnjudged < notes.count else { return }
        let note = notes[firstUnjudged]
        // Only presses aimed at the next note count; an early correct press is fine.
        guard note.time - songTime(now: now) <= Judge.good + windowBonus else { return }

        if keyId == note.keyId {
            notes[firstUnjudged].judgment = .perfect
            scoreboard.noteJudged()
            record(JudgmentEvent(keyId: keyId, judgment: .perfect, hostTime: now))
            beginHold(at: firstUnjudged)
            wrongPressesOnCurrentNote = 0
            if hintKeyId != nil { hintKeyId = nil }
            if isWaiting {
                isWaiting = false
                clock.resume(at: now)
                onClockEvent?(.running(songTime: note.time, hostTime: now))
            }
            advanceFirstUnjudged()
            finishIfDone(now: now)
        } else {
            scoreboard.registerWrongPress(keyId: keyId, breaksCombo: false)
            wrongPressesOnCurrentNote += 1
            record(JudgmentEvent(keyId: keyId, judgment: nil, hostTime: now))
            onJudgment?(nil)
            if wrongPressesOnCurrentNote >= Self.practiceHintWrongPresses, hintKeyId != note.keyId {
                hintKeyId = note.keyId
            }
        }
    }

    /// A key went up (the finger lifted or slid off). Ends the hold on that key, if any: at the tail it is
    /// complete, earlier it is broken (Perform loses the combo and the hold bonus).
    /// The microphone never calls this, so its holds always run to the tail.
    func release(keyId: Int, now: CFTimeInterval) {
        // A finger lifting onto the pause overlay mustn't break the hold; it ends at the tail instead.
        guard phase == .countIn || phase == .playing, let index = holding[keyId] else { return }
        holding[keyId] = nil
        if inputTime(now: now) >= notes[index].holdEnd - Judge.holdReleaseTolerance {
            completeHold(at: index)
        } else {
            notes[index].hold = .broken(at: songTime(now: now))
            if mode == .perform { scoreboard.breakCombo() }
        }
        finishIfDone(now: now)
    }

    private func beginHold(at index: Int) {
        guard notes[index].isHold else { return }
        let keyId = notes[index].keyId
        // A new hold on the same key ends the old one (two fingers, or Listen's repeated key).
        if let previous = holding[keyId] { completeHold(at: previous) }
        notes[index].hold = .holding
        holding[keyId] = index
    }

    private func completeHold(at index: Int) {
        holding[notes[index].keyId] = nil
        notes[index].hold = .completed
        if mode == .perform {
            scoreboard.registerHoldBonus(points: Judge.holdBonus * Judge.multiplier(forCombo: scoreboard.combo))
        }
    }

    /// Holds whose tail has reached the hit line are complete, released or not.
    private func completeDueHolds(t: Double) {
        guard !holding.isEmpty else { return }
        for index in holding.values where t >= notes[index].holdEnd {
            completeHold(at: index)
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
        completeDueHolds(t: mode == .listen ? t : inputTime(now: now))
        switch mode {
        case .perform: stepPerform(now: now)
        case .practice: stepPractice(now: now, t: t)
        case .listen: stepListen(now: now, t: t)
        }
    }

    private func stepPerform(now: CFTimeInterval) {
        let t = inputTime(now: now)
        var missed = 0
        var i = firstUnjudged
        while i < notes.count {
            if notes[i].judgment != nil { i += 1; continue }
            guard t - notes[i].time > Judge.good + windowBonus else { break }   // sorted: nothing later has expired either
            notes[i].judgment = .miss
            record(JudgmentEvent(keyId: notes[i].keyId, judgment: .miss, hostTime: now))
            missed += 1
            i += 1
        }
        if missed > 0 {
            scoreboard.registerMisses(missed)
            for _ in 0..<missed { onJudgment?(.miss) }
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
                onClockEvent?(.halted(songTime: note.time))
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
            scoreboard.noteJudged()
            due = firstUnjudged
            firstUnjudged += 1
        }
        if let due {
            stopListenSound()
            let note = notes[due]
            soundPlayer(NoteCatalog.note(note.keyId).sound)
            listenActiveIndex = due
            hintKeyId = note.keyId
            beginHold(at: due)
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

    /// Perform and Practice finish when every note has been judged and the last hold has ended.
    private func finishIfDone(now: CFTimeInterval) {
        guard mode != .listen, firstUnjudged >= notes.count, holding.isEmpty else { return }
        finish(now: now)
    }

    private func finish(now: CFTimeInterval) {
        guard phase != .finished else { return }
        stopListenSound()
        clock.pause(at: now)
        isWaiting = false
        for index in holding.values { notes[index].hold = .completed }
        holding = [:]
        if hintKeyId != nil { hintKeyId = nil }
        phase = .finished
        onClockEvent?(.finished)
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
        // With the ticker gone nothing would ever end a Listen note that is still sounding.
        stopListenSound()
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
