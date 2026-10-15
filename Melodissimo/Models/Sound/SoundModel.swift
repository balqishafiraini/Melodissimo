//
//  SoundModel.swift
//  Melodissimo
//
//  Created by Balqis on 15/10/23.
//

import Foundation
import AVFoundation

// The note samples play on `NoteAudioEngine` (one `AVAudioEngine`, PCM buffers decoded once, a pool of voices);
// these free functions are the app's whole interface to it. The audio session belongs to `AudioSessionController`.

/// Makes sure the shared audio session exists and is active before a sound plays. The session itself, its
/// interruptions and its route changes belong to `AudioSessionController`; this only asks for the playback
/// mode when nothing has activated a mode yet.
func configureAudioSessionIfNeeded() {
    let controller = AudioSessionController.shared
    if controller.mode == nil { controller.activate(.playback) }
}

/// Decodes all 32 note samples on a background queue and starts the engine, so the first tap on any key sounds
/// instantly. Call once at launch. `completion` runs on the main thread when the samples are ready.
func preloadAllSounds(completion: (() -> Void)? = nil) {
    NoteAudioEngine.shared.preloadNotes(completion: completion)
}

/// How many note samples are decoded and ready to play.
var preloadedSoundCount: Int { NoteAudioEngine.shared.noteBufferCount }

func playSound(key: String) {
    NoteAudioEngine.shared.play(note: key)
}

/// Releases the note that was played last.
func stopSound() {
    NoteAudioEngine.shared.stopLast()
}

/// Releases one note's sample and leaves any other sounding notes alone, so several
/// fingers can hold different keys at once.
func stopSound(key: String) {
    NoteAudioEngine.shared.stop(note: key)
}

/// Silences every note that is sounding, whoever started it (a finger, autoplay, a hint).
/// Called when a screen goes away so no sample outlives the screen that played it.
func stopAllSounds() {
    NoteAudioEngine.shared.stopAllNotes()
}
