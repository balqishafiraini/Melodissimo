//
//  SoundModel.swift
//  Melodissimo
//
//  Created by Balqis on 15/10/23.
//

import Foundation
import AVFoundation
import AVKit

// Reference to the player that is currently sounding, so `stopSound()` can halt it.
private var player: AVAudioPlayer?

// Cache of preloaded players keyed by note name. Each note's audio file is decoded
// from disk only once and reused on every subsequent tap, so tile presses stay
// instant instead of re-decoding the m4a each time.
private var playerCache: [String: AVAudioPlayer] = [:]

private var isAudioSessionConfigured = false

// Configure the shared audio session for playback so notes are audible even when
// the device's mute switch is on. Runs once, lazily, before the first sound plays.
// A small IO buffer keeps tap-to-sound latency low, which matters for the rhythm game.
private func configureAudioSessionIfNeeded() {
    guard !isAudioSessionConfigured else { return }
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playback, mode: .default)
        try? session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        isAudioSessionConfigured = true
    } catch {
        print("Failed to configure audio session: \(error)")
    }
}

/// Decodes one note's sample and gets it ready to play. Safe to call off the main thread.
private func makePlayer(for key: String) -> AVAudioPlayer? {
    guard let url = Bundle.main.url(forResource: key, withExtension: "m4a") else {
        return nil
    }
    do {
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.prepareToPlay()
        return newPlayer
    } catch {
        print("\(error)")
        return nil
    }
}

// Return a cached player for the note, creating and preparing it on first use.
private func cachedPlayer(for key: String) -> AVAudioPlayer? {
    if let existing = playerCache[key] {
        return existing
    }
    guard let newPlayer = makePlayer(for: key) else {
        return nil
    }
    playerCache[key] = newPlayer
    return newPlayer
}

/// Decodes all 32 note samples on a background queue, then stores the players in the
/// cache on the main thread so the first tap on any key sounds instantly. Call once
/// at launch. `completion` runs on the main thread when the cache is warm.
func preloadAllSounds(completion: (() -> Void)? = nil) {
    DispatchQueue.global(qos: .userInitiated).async {
        var loaded: [String: AVAudioPlayer] = [:]
        for note in NoteCatalog.all {
            if let notePlayer = makePlayer(for: note.sound) {
                loaded[note.sound] = notePlayer
            }
        }
        DispatchQueue.main.async {
            for (key, notePlayer) in loaded where playerCache[key] == nil {
                playerCache[key] = notePlayer
            }
            configureAudioSessionIfNeeded()
            completion?()
        }
    }
}

/// How many note samples are decoded and ready to play.
var preloadedSoundCount: Int { playerCache.count }

func playSound(key: String) {
    configureAudioSessionIfNeeded()
    guard let notePlayer = cachedPlayer(for: key) else {
        return
    }
    notePlayer.currentTime = 0
    notePlayer.play()
    player = notePlayer
}

func stopSound() {
    // Stop the player that is currently sounding.
    player?.stop()
}

/// Stops one note's sample and leaves any other sounding notes alone, so several
/// fingers can hold different keys at once.
func stopSound(key: String) {
    playerCache[key]?.stop()
}
