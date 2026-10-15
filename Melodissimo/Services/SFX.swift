//
//  SFX.swift
//  Melodissimo
//

import Foundation
import AVFoundation

/// Short game sounds (hits, misses, coins, stars, clicks). They are decoded once into buffers and play on the
/// effect voices of `NoteAudioEngine`, at a lower volume than the note samples, so they mix with the pianika
/// instead of cutting it off. A sound whose file is missing, or every sound while the setting is off, is
/// silently skipped.
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

    private let bundle: Bundle
    private let isEnabled: () -> Bool
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var missing: Set<String> = []

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
        guard isEnabled(), let buffer = buffer(for: resource) else { return false }
        NoteAudioEngine.shared.playEffect(buffer)
        return true
    }

    /// Whether the file for this resource is in the bundle and decodes.
    func canPlay(_ resource: String) -> Bool {
        buffer(for: resource) != nil
    }

    /// Decodes every effect on a background queue, then hands the buffers over on the main thread, so the first
    /// effect in a play doesn't hitch and launch isn't held up by the decoding. An effect played before this
    /// finishes just decodes itself, as it always did. Call once at launch; `completion` runs on the main thread
    /// when the buffers are ready.
    func preload(completion: (() -> Void)? = nil) {
        let bundle = self.bundle
        DispatchQueue.global(qos: .userInitiated).async {
            var decoded: [String: AVAudioPCMBuffer] = [:]
            for effect in Effect.allCases {
                if let url = bundle.url(forResource: effect.rawValue, withExtension: Self.fileExtension),
                   let buffer = NoteAudioEngine.makeBuffer(url: url) {
                    decoded[effect.rawValue] = buffer
                }
            }
            DispatchQueue.main.async {
                for (resource, buffer) in decoded where self.buffers[resource] == nil {
                    self.buffers[resource] = buffer
                }
                completion?()
            }
        }
    }

    /// A sound's buffer, decoded on first use, or `nil` when the file isn't in the bundle or doesn't decode.
    private func buffer(for resource: String) -> AVAudioPCMBuffer? {
        if missing.contains(resource) { return nil }
        if let buffer = buffers[resource] { return buffer }
        guard let url = bundle.url(forResource: resource, withExtension: Self.fileExtension),
              let buffer = NoteAudioEngine.makeBuffer(url: url) else {
            missing.insert(resource)
            return nil
        }
        buffers[resource] = buffer
        return buffer
    }
}
