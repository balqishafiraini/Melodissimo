//
//  VoiceAllocator.swift
//  Melodissimo
//

import Foundation

/// Hands out the fixed pool of note voices (`AVAudioPlayerNode`s) and remembers who owns which. It is only
/// bookkeeping, so it is tested without any audio: the engine asks it which voice to use and whether a delayed
/// fade-out is still about to stop the voice it started.
///
/// - A note that already has a voice gets that same voice again (the old sound is cut, as a key pressed twice
///   always did).
/// - Otherwise the voice that has been free the longest is used, and when every voice is busy the oldest one is
///   stolen. A voice stays "owned" after its sample ended on its own, since the audio thread must not touch state;
///   stealing the oldest picks such a voice in practice, and cutting a finished voice costs nothing.
/// - Every start bumps the voice's `generation`. A fade-out carries the generation it began with and does nothing
///   if the voice has been restarted or stolen in the meantime, so a late stop never cuts a newer sound.
struct VoiceAllocator {
    struct Voice: Equatable {
        var note: String?
        var generation = 0
        var startedAt = 0
    }

    /// Which voice a start uses, and the generation to pass to a later `release` / `finishRelease`.
    struct Start: Equatable {
        let voice: Int
        let generation: Int
    }

    private(set) var voices: [Voice]
    private var tick = 0

    init(count: Int) {
        precondition(count > 0)
        voices = Array(repeating: Voice(), count: count)
    }

    /// The voice to play `note` on.
    mutating func start(note: String) -> Start {
        let index: Int
        if let own = voice(for: note) {
            index = own
        } else if let free = voices.indices.filter({ voices[$0].note == nil }).min(by: { voices[$0].startedAt < voices[$1].startedAt }) {
            index = free
        } else {
            index = voices.indices.min(by: { voices[$0].startedAt < voices[$1].startedAt })!
        }
        tick += 1
        voices[index].note = note
        voices[index].generation += 1
        voices[index].startedAt = tick
        return Start(voice: index, generation: voices[index].generation)
    }

    /// The voice currently owned by `note`.
    func voice(for note: String) -> Int? {
        voices.indices.first { voices[$0].note == note }
    }

    /// Whether the voice still belongs to the start that returned `generation`.
    func isCurrent(voice: Int, generation: Int) -> Bool {
        voices.indices.contains(voice) && voices[voice].generation == generation
    }

    /// The start to fade out for `note`, or `nil` when the note has no voice.
    func release(note: String) -> Start? {
        voice(for: note).map { Start(voice: $0, generation: voices[$0].generation) }
    }

    /// Ends a fade-out: frees the voice, unless it was restarted or stolen since. Returns whether it was freed,
    /// i.e. whether the caller should really stop the node.
    @discardableResult
    mutating func finishRelease(_ start: Start) -> Bool {
        guard isCurrent(voice: start.voice, generation: start.generation) else { return false }
        voices[start.voice].note = nil
        return true
    }

    /// Frees every voice at once and returns the ones that were owned, so the caller stops those nodes.
    /// Pending fade-outs become stale.
    mutating func stopAll() -> [Int] {
        var stopped: [Int] = []
        for index in voices.indices where voices[index].note != nil {
            voices[index].note = nil
            voices[index].generation += 1
            stopped.append(index)
        }
        return stopped
    }
}
