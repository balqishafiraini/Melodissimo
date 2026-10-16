//
//  ShopView.swift
//  Melodissimo
//

import SwiftUI

/// What a tab of the shop shows.
enum ShopTab: Hashable {
    case category(ShopCategory)
    /// Coin packs bought with real money.
    case coins
}

/// Spend coins on cosmetics (keyboard skins, falling-note skins, Alpanica's outfits) and hearts, or buy coin
/// packs with real money. Buying a cosmetic asks first; owned items can be worn or swapped at any time.
struct ShopView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var store = StoreService.shared

    @State private var tab: ShopTab
    @State private var itemToBuy: ShopItem?
    /// Achievements a purchase just unlocked (the Kolektor), shown for a few seconds.
    @State private var unlockedTitles: [String] = []
    /// The last coin-pack purchase that did not simply succeed, shown under the tabs.
    @State private var storeMessage: LocalizedStringKey?
    @State private var isBuyingProduct = false

    private let columns = [GridItem(.adaptive(minimum: Sizing.isPhone ? 150 : 230), spacing: Sizing.isPhone ? 10 : 20)]

    init(startAtCoins: Bool = false) {
        _tab = State(initialValue: startAtCoins ? .coins : .category(.keyboard))
    }

    /// Tabs come from the data: categories that have something to show, then the coin packs.
    private var tabs: [ShopTab] {
        var list = ShopCatalog.visibleCategories(owned: progress.purchasedShopItemIds).map(ShopTab.category)
        if !ProductCatalog.consumablesOnSale(granted: PurchaseGrants.ledger(in: progress)).isEmpty { list.append(.coins) }
        return list
    }

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue)

            VStack(spacing: Sizing.s(18)) {
                topBar
                tabBar
                if let storeMessage {
                    Text(storeMessage)
                        .font(.headline)
                        .foregroundColor(Color.darkGreen)
                }
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Sizing.isPhone ? 10 : 20) {
                        switch tab {
                        case .category(let category):
                            ForEach(ShopCatalog.visibleItems(in: category, owned: progress.purchasedShopItemIds)) { item in
                                card(for: item)
                            }
                        case .coins:
                            ForEach(ProductCatalog.consumablesOnSale(granted: PurchaseGrants.ledger(in: progress))) { product in
                                coinCard(for: product)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(Sizing.s(30))
        }
        .overlay(alignment: .bottom) {
            if !unlockedTitles.isEmpty {
                AchievementBanner(titles: unlockedTitles)
                    .padding(.bottom, Sizing.s(24))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert(Text("Buy \(itemToBuy?.name ?? "")?"),
               isPresented: Binding(get: { itemToBuy != nil }, set: { if !$0 { itemToBuy = nil } }),
               presenting: itemToBuy) { item in
            Button("Buy") { buy(item) }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("It costs \(item.price) coins.")
        }
        .task { await store.loadProducts() }
    }

    // MARK: Pieces

    private var topBar: some View {
        ZStack {
            Text("Shop")
                .font(Font.largeTitle)
                .foregroundColor(Color.darkGreen)

            HStack {
                SoundButton {
                    router.pop()
                } label: {
                    Text("Menu")
                        .buttonFrame(width: 120, height: 80)
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(Sizing.s(20))
                        .font(Font.headline)
                }
                Spacer()
                SoundButton {
                    tab = .coins
                } label: {
                    CoinBadge(height: Sizing.tap(80))
                }
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: Sizing.s(14)) {
            ForEach(tabs, id: \.self) { entry in
                SoundButton {
                    tab = entry
                    storeMessage = nil
                } label: {
                    Text(Self.title(of: entry))
                        .frame(maxWidth: .infinity)
                        .frame(height: Sizing.tap(60))
                        .background(tab == entry ? Color.darkGreen : Color.white)
                        .foregroundColor(tab == entry ? .white : Color.darkGreen)
                        .cornerRadius(Sizing.s(20))
                        .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
        }
    }

    private static func title(of tab: ShopTab) -> LocalizedStringKey {
        switch tab {
        case .category(.keyboard): return "Keyboard"
        case .category(.notes): return "Notes"
        case .category(.outfit): return "Outfit"
        case .category(.boost): return "Hearts"
        case .coins: return "Coins"
        }
    }

    private func card(for item: ShopItem) -> some View {
        VStack(spacing: Sizing.isPhone ? 4 : 10) {
            Group {
                if Sizing.isPhone {
                    // The previews are drawn at the iPad's size; here they are shrunk to a small thumbnail.
                    preview(for: item)
                        .frame(width: 190, height: 130)
                        .scaleEffect(0.55)
                        .frame(width: 105, height: 72)
                } else {
                    preview(for: item)
                        .frame(height: 130)
                }
            }
            Text(LocalizedStringKey(item.name))
                .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(Color.darkGreen)
            if let note = availabilityNote(for: item) {
                Text(note)
                    .font(.caption)
                    .foregroundColor(Color.darkGreen.opacity(0.7))
            }
            if item.kind == .consumable {
                consumableButtons(for: item)
            } else {
                actionButton(for: item)
            }
        }
        .padding(Sizing.isPhone ? 8 : 16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Sizing.s(28)).fill(Color.white))
        .overlay(alignment: .topTrailing) { tagBadge(for: item) }
    }

    /// "New" and "Sale" for items that carry those tags. `plusOnly` items show no badge until Plus exists (Task B7.3).
    @ViewBuilder
    private func tagBadge(for item: ShopItem) -> some View {
        if item.tags.contains("sale") || item.tags.contains("new") {
            Text(item.tags.contains("sale") ? "Sale" : "New")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(item.tags.contains("sale") ? Color.red : Color.green))
                .foregroundColor(.white)
                .padding(8)
        }
    }

    /// "Ends in N days" while an item has an end date within the next two weeks.
    private func availabilityNote(for item: ShopItem) -> LocalizedStringKey? {
        guard let until = item.availableUntil else { return nil }
        let days = Int(until.timeIntervalSinceNow / 86_400)
        guard until > Date(), days <= 14 else { return nil }
        return days <= 0 ? "Ends today" : "Ends in \(days) days"
    }

    @ViewBuilder
    private func preview(for item: ShopItem) -> some View {
        switch item.category {
        case .keyboard:
            KeyboardPreview(skin: KeyboardSkin(item: item))
        case .notes:
            NotesPreview(skin: NoteSkin(itemId: item.id))
        case .outfit:
            // A tinted backdrop, so the white alpaca doesn't vanish into the white card.
            ArtImage(source: AlpanicaOutfit(item: item).preview)
                .padding(6)
                .frame(width: 190)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.softBlue.opacity(0.6)))
        case .boost:
            AssetImage(name: item.bundledArt?.preview ?? "", fallbackEmoji: "❤️")
                .padding(6)
        }
    }

    /// Equipped, Equip or Buy, depending on what the player has done with the item.
    @ViewBuilder
    private func actionButton(for item: ShopItem) -> some View {
        if progress.equippedItem(item.category) == item {
            Label("Equipped", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.tap(52))
                .foregroundColor(Color.green)
                .font(.headline)
        } else if progress.owns(item) {
            SoundButton {
                progress.equip(item)
            } label: {
                Text("Equip")
                    .frame(maxWidth: .infinity)
                    .frame(height: Sizing.tap(52))
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(Sizing.s(16))
                    .font(.headline)
            }
        } else {
            priceButton(price: item.price) { itemToBuy = item }
        }
    }

    /// A consumable shows how many the player holds and buys one or five at a time.
    private func consumableButtons(for item: ShopItem) -> some View {
        let stack = item.maxStack ?? ProgressStore.defaultMaxStack
        return VStack(spacing: Sizing.isPhone ? 4 : 8) {
            Text("You have \(progress.inventoryCount(item.id, maxStack: stack))")
                .font(.headline)
                .foregroundColor(Color.darkGreen)
            HStack(spacing: Sizing.s(8)) {
                ForEach([1, 5], id: \.self) { count in
                    priceButton(price: item.price * count, label: "×\(count)") {
                        if progress.buyConsumable(item, count: count, maxStack: stack) {
                            SFX.play(.coin)
                        }
                    }
                }
            }
        }
    }

    private func priceButton(price: Int, label: String? = nil, action: @escaping () -> Void) -> some View {
        let canAfford = progress.coinBalance >= price
        return SoundButton {
            action()
        } label: {
            HStack(spacing: 6) {
                if let label { Text(label) }
                AssetImage(name: "icon_coin", fallbackEmoji: "🪙")
                    .frame(width: Sizing.s(30), height: Sizing.s(30))
                Text("\(price)")
            }
            .frame(maxWidth: .infinity)
            .frame(height: Sizing.tap(52))
            .background(canAfford ? Color.yellow : Color.gray.opacity(0.35))
            .foregroundColor(canAfford ? Color.darkGreen : Color.darkGreen.opacity(0.5))
            .cornerRadius(Sizing.s(16))
            .font(.custom("BalooDa-Regular", size: Sizing.f(26)))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        }
        .disabled(!canAfford)
        .accessibilityHint(canAfford ? Text("") : Text("Not enough coins"))
    }

    // MARK: Coin packs

    private func coinCard(for product: StoreProduct) -> some View {
        let grants = product.grants ?? PurchaseGrant()
        return VStack(spacing: Sizing.isPhone ? 6 : 12) {
            AssetImage(name: "icon_coin", fallbackEmoji: "🪙")
                .frame(height: Sizing.isPhone ? 56 : 90)
            Text("\(grants.coins) coins")
                .font(.custom("BalooDa-Regular", size: Sizing.f(30)))
                .foregroundColor(Color.darkGreen)
            if let hearts = grants.items[ReviveRules.heartItemId] {
                Text("+ \(hearts) hearts")
                    .font(.headline)
                    .foregroundColor(Color.darkGreen)
            }
            SoundButton {
                buyProduct(product)
            } label: {
                Text(store.displayPrice(for: product.id) ?? "…")
                    .frame(maxWidth: .infinity)
                    .frame(height: Sizing.tap(52))
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(Sizing.s(16))
                    .font(.headline)
            }
            .disabled(store.displayPrice(for: product.id) == nil || isBuyingProduct)
        }
        .padding(Sizing.isPhone ? 8 : 16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Sizing.s(28)).fill(Color.white))
        .overlay(alignment: .topTrailing) {
            if let badge = product.badge {
                Text(badge == "popular" ? "Popular" : (badge == "bestValue" ? "Best value" : "Special"))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red))
                    .foregroundColor(.white)
                    .padding(8)
            }
        }
    }

    private func buyProduct(_ product: StoreProduct) {
        isBuyingProduct = true
        storeMessage = nil
        Task {
            let outcome = await store.buy(product.id)
            isBuyingProduct = false
            switch outcome {
            case .success: SFX.play(.coin)
            case .pending: storeMessage = "Waiting for approval"
            case .cancelled: break
            case .failed: storeMessage = "The purchase did not go through"
            }
        }
    }

    private func buy(_ item: ShopItem) {
        // Wear a new purchase right away, since that is what people want to see.
        if progress.buy(item) {
            progress.equip(item)
            SFX.play(.coin)
            showUnlocked(AchievementStore.shared.evaluate().map(\.title))
        }
    }

    private func showUnlocked(_ titles: [String]) {
        guard !titles.isEmpty else { return }
        withAnimation { unlockedTitles = titles }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation { unlockedTitles = [] }
        }
    }
}

// MARK: - Previews

/// A little keyboard in the skin's colours, with one key pressed.
private struct KeyboardPreview: View {
    let skin: KeyboardSkin

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(skin.body)
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(index == 3 ? skin.pressed : Color.white)
                }
            }
            .padding(10)
            HStack(spacing: 0) {
                ForEach([0, 1, 3, 4, 5], id: \.self) { slot in
                    Color.black
                        .frame(width: 12, height: 52)
                        .cornerRadius(3)
                        .frame(width: 22)
                        .opacity(slot < 6 ? 1 : 0)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 10)
        }
        .frame(width: 190)
    }
}

/// A few falling notes in the skin's colours: three white-key notes and one black-key note.
private struct NotesPreview: View {
    let skin: NoteSkin

    private let notes: [(semitone: Int, isBlack: Bool)] = [(0, false), (2, false), (4, false), (3, true)]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.navy.opacity(0.9))
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(notes.enumerated()), id: \.offset) { offset, note in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(skin.color(semitone: note.semitone, isBlack: note.isBlack)
                              ?? (note.isBlack ? Color.navy : Color.yellow))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.85), lineWidth: 2))
                        .frame(width: 30, height: CGFloat(40 + offset * 18))
                }
            }
            .padding(.bottom, 12)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 190)
    }
}
