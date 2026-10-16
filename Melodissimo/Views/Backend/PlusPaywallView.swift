//
//  PlusPaywallView.swift
//  Melodissimo
//

import SwiftUI

/// Melodissimo Plus: every song pack, now and later. Monthly and yearly plans with prices straight from the store, the yearly
/// saving worked out from the two prices, the free-trial text when the player is eligible, Subscribe, Restore and the
/// Terms of Use and Privacy Policy links that App Review requires (3.1.2). No countdowns or pressure: the players are kids.
struct PlusPaywallView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var store = StoreService.shared
    @ObservedObject private var entitlements = Entitlements.shared
    @Environment(\.openURL) private var openURL

    private static let monthlyId = "melodissimo.plus.monthly"
    private static let yearlyId = "melodissimo.plus.yearly"

    @State private var monthly: StoreService.Offer?
    @State private var yearly: StoreService.Offer?
    @State private var selected = PlusPaywallView.yearlyId
    @State private var message: LocalizedStringKey?
    @State private var isWorking = false

    private var saving: Int? { PlusPricing.yearlySavingPercent(monthly: monthly?.price, yearly: yearly?.price) }

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue)
            VStack(spacing: Sizing.s(16)) {
                topBar
                ScrollView {
                    VStack(spacing: Sizing.s(16)) {
                        Text("Melodissimo Plus")
                            .font(.custom("BalooDa-Regular", size: Sizing.f(46)))
                            .foregroundColor(Color.darkGreen)
                        VStack(alignment: .leading, spacing: Sizing.s(8)) {
                            benefit("Every song pack, including the ones we add later")
                            benefit("A free “Continue?” in every game")
                            benefit("Everything you already have stays free")
                        }
                        if entitlements.isPlusActive {
                            Label("You have Plus", systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundColor(Color.darkGreen)
                        } else {
                            HStack(spacing: Sizing.s(12)) {
                                plan(id: Self.monthlyId, title: "Monthly", offer: monthly)
                                plan(id: Self.yearlyId, title: "Yearly", offer: yearly, badge: saving.map { LocalizedStringKey("Save \($0)%") })
                            }
                            if let trial = (selected == Self.yearlyId ? yearly : monthly)?.trialText {
                                Text(trial)
                                    .font(.headline)
                                    .foregroundColor(Color.darkGreen)
                            }
                            subscribeButton
                        }
                        if let message {
                            Text(message).font(.subheadline).foregroundColor(Color.darkGreen)
                        }
                        footer
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, Sizing.s(20))
                }
            }
            .padding(Sizing.s(24))
        }
        .onAppear { Analytics.log(.paywallView, props: ["kind": "plus"]) }
        .task {
            await store.loadProducts()
            monthly = await store.offer(for: Self.monthlyId)
            yearly = await store.offer(for: Self.yearlyId)
        }
    }

    private var topBar: some View {
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

    private func benefit(_ text: LocalizedStringKey) -> some View {
        Label { Text(text).font(.headline).foregroundColor(Color.darkGreen) } icon: {
            Image(systemName: "music.note").foregroundColor(Color.darkGreen)
        }
    }

    private func plan(id: String, title: LocalizedStringKey, offer: StoreService.Offer?, badge: LocalizedStringKey? = nil) -> some View {
        SoundButton {
            selected = id
        } label: {
            VStack(spacing: 4) {
                Text(title).font(.headline)
                Text(offer?.displayPrice ?? "…").font(.custom("BalooDa-Regular", size: Sizing.f(30)))
                if let badge { Text(badge).font(.caption.bold()) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Sizing.s(14))
            .background(RoundedRectangle(cornerRadius: Sizing.s(20)).fill(selected == id ? Color.darkGreen : Color.white))
            .foregroundColor(selected == id ? .white : Color.darkGreen)
        }
    }

    private var subscribeButton: some View {
        SoundButton {
            Task { await subscribe() }
        } label: {
            Text("Subscribe")
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.tap(64))
                .background(Color.yellow)
                .foregroundColor(Color.darkGreen)
                .cornerRadius(Sizing.s(20))
                .font(.custom("BalooDa-Regular", size: Sizing.f(32)))
        }
        .disabled(isWorking || store.displayPrice(for: selected) == nil)
    }

    private var footer: some View {
        VStack(spacing: Sizing.s(8)) {
            SoundButton {
                Task { await store.restore() }
            } label: {
                Text("Restore purchases").font(.subheadline.bold()).foregroundColor(Color.darkGreen)
            }
            HStack(spacing: Sizing.s(16)) {
                if let terms = LegalLinks.terms { Button("Terms of Use") { openURL(terms) } }
                if let privacy = LegalLinks.privacy { Button("Privacy Policy") { openURL(privacy) } }
            }
            .font(.footnote)
            Text("The subscription renews automatically until you cancel it in your App Store settings.")
                .font(.footnote)
                .foregroundColor(Color.darkGreen.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private func subscribe() async {
        isWorking = true
        defer { isWorking = false }
        message = nil
        switch await store.buy(selected) {
        case .success: message = "Welcome to Plus!"
        case .pending: message = "Waiting for approval"
        case .cancelled: break
        case .failed: message = "The purchase did not go through"
        }
    }
}
