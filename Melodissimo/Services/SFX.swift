//
//  SFX.swift
//  Melodissimo
//

import Foundation
import AVFoundation

/// Short game sounds (hits, misses, coins, stars, clicks). They play on their own cached players, at a
/// lower volume than the note samples, so they mix with the pianika instead of cutting it off. A sound
/// whose file is missing, or every sound while the setting is off, is silently skipped.
final class SFX {

    /// The sounds the game uses. The raw values are the bundled file names (`<name>.caf`).
    enum Effect: String, CaseIterable {
        case perfect = "sfx_perfect"
        case miss = "sfx_miss"
        case wrong = "sfx_wrong"
        case coin = "sfx_coin"
        case star = "sfx_star"
        case unlock = "sfx_unlock"
        case monsterHit = "sfx_monster_hit"
        case playerHurt = "sfx_player_hurt"
        case tick = "sfx_tick"
        case button = "sfx_button"
    }

    static let shared = SFX()

    /// Effects play at 60 % so the note samples stay in front.
    static let volume: Float = 0.6
    static let fileExtension = "caf"
    /// How many copies of one sound can overlap (rapid Perfects, a run of clicks).
    private static let voicesPerEffect = 3

    private let bundle: Bundle
    private let isEnabled: () -> Bool
    private var pools: [String: [AVAudioPlayer]] = [:]
    private var missing: Set<String> = []
    private var nextVoice: [String: Int] = [:]

    init(bundle: Bundle = .main, isEnabled: @escaping () -> Bool = { ProgressStore.shared.sfxEnabled }) {
        self.bundle = bundle
        self.isEnabled = isEnabled
    }

    /// Plays an effect on the shared instance.
    static func play(_ effect: Effect) {
        shared.play(effect.rawValue)
    }

    /// Plays the sound with this resource name. Returns `false`, doing nothing, when the setting is off or
    /// the file isn't in the bundle.
    @discardableResult
    func play(_ resource: String) -> Bool {
        guard isEnabled(), let voice = nextPlayer(for: resource) else { return false }
        configureAudioSessionIfNeeded()
        voice.currentTime = 0
        return voice.play()
    }

    /// Whether the file for this resource is in the bundle and decodes.
    func canPlay(_ resource: String) -> Bool {
        nextPlayer(for: resource) != nil
    }

    /// Decodes every effect on a background queue, then hands the players over on the main thread, so the first
    /// effect in a play doesn't hitch and launch isn't held up by the decoding (about a second on a simulator).
    /// An effect played before this finishes just builds its own players, as it always did. Call once at launch;
    /// `completion` runs on the main thread when the pools are warm.
    func preload(completion: (() -> Void)? = nil) {
        let bundle = self.bundle
        DispatchQueue.global(qos: .userInitiated).async {
            var decoded: [String: [AVAudioPlayer]] = [:]
            for effect in Effect.allCases {
                if let players = Self.makePlayers(for: effect.rawValue, in: bundle) {
                    decoded[effect.rawValue] = players
                }
            }
            DispatchQueue.main.async {
                for (resource, players) in decoded where self.pools[resource] == nil {
                    self.pools[resource] = players
                }
                completion?()
            }
        }
    }

    /// A sound's few ready-to-play players, or `nil` when the file isn't in the bundle or doesn't decode.
    /// Touches no state, so it is safe off the main thread.
    private static func makePlayers(for resource: String, in bundle: Bundle) -> [AVAudioPlayer]? {
        guard let url = bundle.url(forResource: resource, withExtension: fileExtension) else { return nil }
        let players: [AVAudioPlayer] = (0..<voicesPerEffect).compactMap { _ in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.volume = volume
            player.prepareToPlay()
            return player
        }
        return players.isEmpty ? nil : players
    }

    /// The next of a sound's few players, taking turns so a fast repeat doesn't restart the one still sounding.
    private func nextPlayer(for resource: String) -> AVAudioPlayer? {
        if missing.contains(resource) { return nil }
        if pools[resource] == nil {
            guard let players = Self.makePlayers(for: resource, in: bundle) else {
                missing.insert(resource)
                return nil
            }
            pools[resource] = players
        }
        guard let pool = pools[resource] else { return nil }
        let index = (nextVoice[resource] ?? 0) % pool.count
        nextVoice[resource] = index + 1
        return pool[index]
    }
}
