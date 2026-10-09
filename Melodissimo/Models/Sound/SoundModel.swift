//
//  SoundModel.swift
//  Melodissimo
//
//  Created by Balqis on 15/10/23.
//

import Foundation
import AVFoundation
import AVKit

var player: AVAudioPlayer?

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

func playSound (key: String) {
    configureAudioSessionIfNeeded()
    let url = Bundle.main.url(forResource: key, withExtension: "m4a")
    guard url != nil else {
        return
    }
    do {
        player = try AVAudioPlayer(contentsOf: url!)
        player?.play()
    } catch {
        print("\(error)")
    }
}

func stopSound() {
        // Stop AVAudioPlayer
    player?.stop()
    }
