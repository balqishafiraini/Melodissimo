//
//  PackStoreView.swift
//  Melodissimo
//

import SwiftUI

/// The song packs on sale, plus a Plus card. Reachable from Home and Free Play while the `packStore` flag is on.
struct PackStoreView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var entitlements = Entitlements.shared
    @ObservedObject private var content = ContentStore.shared
    @ObservedObject private var bootstrap = BootstrapService.shared

    /// Packs to show: every paid pack the player's country may see. The free core pack is not for sale. A pack the player
    /// already owns stays listed in every country.
    private var packs: [ManifestPack] {
        let storefront = Market.storefront, device = Market.deviceCountry
        let shown = content.packs.filter { pack in
            pack.access.type == "product"
                && (entitlements.isUnlocked(pack) || Markets.allows(pack.markets, storefront: storefront, deviceCountry: device))
        }
        return Markets.featuredFirst(shown, markets: \.markets, storefront: storefront, deviceCountry: device)
    }

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue)
            VStack(spacing: Sizing.s(16)) {
                ZStack {
                    Text("Song Packs").font(Font.largeTitle).foregroundColor(Color.darkGreen)
                    HStack {
                        SoundButton {
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
                }
                ScrollView {
                    VStack(spacing: Sizing.s(14)) {
                        plusCard
                        if packs.isEmpty {
                            Text("New songs are on the way!").font(.headline).foregroundColor(Color.darkGreen)
                        }
                        ForEach(packs) { pack in packCard(pack) }
                    }
                    .frame(maxWidth: 600)
                    .padding(.horizontal, Sizing.s(20))
                }
            }
            .padding(Sizing.s(24))
        }
    }

    private var plusCard: some View {
        SoundButton {
            router.push(.plus)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Melodissimo Plus").font(.custom("BalooDa-Regular", size: Sizing.f(32)))
                    Text("Every pack, now and later").font(.subheadline)
                }
                Spacer()
                if entitlements.isPlusActive { Image(systemName: "checkmark.seal.fill") } else { Image(systemName: "chevron.right") }
            }
            .padding(Sizing.s(18))
            .background(RoundedRectangle(cornerRadius: Sizing.s(24)).fill(Color.darkGreen))
            .foregroundColor(.white)
        }
    }

    private func packCard(_ pack: ManifestPack) -> some View {
        let isOpen = entitlements.isUnlocked(pack)
        let featured = Markets.isFeatured(pack.markets, storefront: Market.storefront, deviceCountry: Market.deviceCountry)
        return SoundButton {
            router.push(.paywall(packId: pack.id))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.title.resolved()).font(.custom("BalooDa-Regular", size: Sizing.f(30)))
                    Text("\(SongLibrary.all.filter { $0.packId == pack.id }.count) songs").font(.subheadline)
                }
                Spacer()
                if featured { Text("Featured").font(.caption.bold()).padding(6).background(Capsule().fill(Color.yellow)) }
                Image(systemName: isOpen ? "checkmark.circle.fill" : "lock.fill")
            }
            .padding(Sizing.s(18))
            .background(RoundedRectangle(cornerRadius: Sizing.s(24)).fill(Color.white))
            .foregroundColor(Color.darkGreen)
        }
    }
}
