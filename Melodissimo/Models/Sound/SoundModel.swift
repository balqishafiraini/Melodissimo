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
private func configureAudioSessionIfNeeded() {
    guard !isAudioSessionConfigured else { return }
    do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        isAudioSessionConfigured = true
    } catch {
        print("Failed to configure audio session: \(error)")
    }
}

// Return a cached player for the note, creating and preparing it on first use.
private func cachedPlayer(for key: String) -> AVAudioPlayer? {
    if let existing = playerCache[key] {
        return existing
    }
    guard let url = Bundle.main.url(forResource: key, withExtension: "m4a") else {
        return nil
    }
    do {
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.prepareToPlay()
        playerCache[key] = newPlayer
        return newPlayer
    } catch {
        print("\(error)")
        return nil
    }
}

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
