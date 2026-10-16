//
//  PaywallView.swift
//  Melodissimo
//

import AVFoundation
import SwiftUI

/// Plays the first 15 seconds of a song's backing track, if it is on the device. For the pack's paywall.
final class PackPreviewPlayer: ObservableObject {
    @Published private(set) var playingSongId: String?
    private var player: AVAudioPlayer?
    private var stopWork: DispatchWorkItem?

    func toggle(songId: String) {
        if playingSongId == songId { stop(); return }
        stop()
        guard let url = BackingTrackPlayer.url(for: songId), let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.8
        player.play()
        self.player = player
        playingSongId = songId
        let work = DispatchWorkItem { [weak self] in self?.stop() }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: work)
    }

    func stop() {
        stopWork?.cancel()
        player?.stop()
        player = nil
        playingSongId = nil
    }

    deinit { player?.stop() }
}

/// One pack: its art, its songs (with a 15-second preview when the audio is already downloaded), the store price, Buy,
/// Restore, and a way to Plus. No countdowns or pressure copy.
struct PaywallView: View {
    let packId: String

    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var store = StoreService.shared
    @ObservedObject private var entitlements = Entitlements.shared
    @ObservedObject private var content = ContentStore.shared
    @StateObject private var preview = PackPreviewPlayer()

    @State private var message: LocalizedStringKey?
    @State private var isWorking = false

    private var pack: ManifestPack? { content.packs.first { $0.id == packId } }
    private var songs: [Song] { SongLibrary.all.filter { $0.packId == packId } }
    /// The one-time product of the pack: a product id that isn't a Plus plan.
    private var packProductId: String? { pack?.access.productIds.first { !Entitlements.isPlusProduct($0) } }

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue)
            VStack(spacing: Sizing.s(16)) {
                HStack {
                    SoundButton {
                        preview.stop()
                        router.pop()
                    } label: {
                        Text("< Back")
                            .padding(.horizontal, 14)
                            .frame(minWidth: Sizing.tap(120), minHeight: Sizing.tap(64))
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(Sizing.s(20))
                            .font(Font.headline)
                    }
                    Spacer()
                }
                if let pack {
                    ScrollView {
                        VStack(spacing: Sizing.s(14)) {
                            if let art = pack.art, let url = content.url(forAsset: art) {
                                ArtImage(source: .file(url), fallbackEmoji: "🎵").frame(height: Sizing.s(140))
                            }
                            Text(pack.title.resolved())
                                .font(.custom("BalooDa-Regular", size: Sizing.f(42)))
                                .foregroundColor(Color.darkGreen)
                            if let description = pack.description?.resolved(), !description.isEmpty {
                                Text(description).font(.headline).foregroundColor(Color.darkGreen).multilineTextAlignment(.center)
                            }
                            ForEach(songs) { song in songRow(song) }
                            actions(for: pack)
                            if let message { Text(message).font(.subheadline).foregroundColor(Color.darkGreen) }
                        }
                        .frame(maxWidth: 560)
                        .padding(.horizontal, Sizing.s(20))
                    }
                } else {
                    Spacer()
                    Text("This pack is not available right now.").font(.headline).foregroundColor(Color.darkGreen)
                    Spacer()
                }
            }
            .padding(Sizing.s(24))
        }
        .task { await store.loadProducts() }
        .onAppear { Analytics.log(.paywallView, props: ["packId": .string(packId), "kind": "pack"]) }
        .onDisappear { preview.stop() }
    }

    private func songRow(_ song: Song) -> some View {
        HStack {
            Text(song.displayTitle).font(.headline).foregroundColor(Color.darkGreen)
            Spacer()
            if BackingTrackPlayer.isAvailable(for: song.id) {
                SoundButton {
                    preview.toggle(songId: song.id)
                } label: {
                    Image(systemName: preview.playingSongId == song.id ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(Color.darkGreen)
                }
                .accessibilityLabel(Text("Preview"))
            }
        }
        .padding(Sizing.s(12))
        .background(RoundedRectangle(cornerRadius: Sizing.s(16)).fill(Color.white))
    }

    @ViewBuilder
    private func actions(for pack: ManifestPack) -> some View {
        if entitlements.isUnlocked(pack) {
            Label("You have this pack", systemImage: "checkmark.seal.fill").font(.headline).foregroundColor(Color.darkGreen)
        } else {
            if let productId = packProductId {
                SoundButton {
                    Task { await buy(productId) }
                } label: {
                    Text(store.displayPrice(for: productId).map { "\(String(localized: "Buy")) · \($0)" } ?? "…")
                        .frame(maxWidth: .infinity)
                        .frame(height: Sizing.tap(64))
                        .background(Color.yellow)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(Sizing.s(20))
                        .font(.custom("BalooDa-Regular", size: Sizing.f(30)))
                }
                .disabled(isWorking || store.displayPrice(for: productId) == nil)
            }
            if pack.access.productIds.contains(where: Entitlements.isPlusProduct) {
                SoundButton {
                    router.push(.plus)
                } label: {
                    Text("Get everything with Plus")
                        .frame(maxWidth: .infinity)
                        .frame(height: Sizing.tap(56))
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(Sizing.s(20))
                        .font(.headline)
                }
            }
            SoundButton {
                Task { await store.restore() }
            } label: {
                Text("Restore purchases").font(.subheadline.bold()).foregroundColor(Color.darkGreen)
            }
        }
    }

    private func buy(_ productId: String) async {
        isWorking = true
        defer { isWorking = false }
        message = nil
        switch await store.buy(productId) {
        case .success: message = "Thank you!"
        case .pending: message = "Waiting for approval"
        case .cancelled: break
        case .failed: message = "The purchase did not go through"
        }
    }
}
