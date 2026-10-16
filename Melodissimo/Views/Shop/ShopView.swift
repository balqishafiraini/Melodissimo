//
//  ShopView.swift
//  Melodissimo
//

import SwiftUI

/// Spend coins on cosmetics: keyboard skins, falling-note skins and Alpanica's outfits. Nothing here
/// is bought with real money. Buying asks first; owned items can be worn or swapped at any time.
struct ShopView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared

    @State private var category: ShopCategory = .keyboard
    @State private var itemToBuy: ShopItem?
    /// Achievements a purchase just unlocked (the Kolektor), shown for a few seconds.
    @State private var unlockedTitles: [String] = []

    private let columns = [GridItem(.adaptive(minimum: Sizing.isPhone ? 150 : 230), spacing: Sizing.isPhone ? 10 : 20)]

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue)

            VStack(spacing: Sizing.s(18)) {
                topBar
                tabs
                ScrollView {
                    LazyVGrid(columns: columns, spacing: Sizing.isPhone ? 10 : 20) {
                        ForEach(ShopCatalog.visibleItems(in: category, owned: progress.purchasedShopItemIds)) { item in
                            card(for: item)
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
                CoinBadge(height: Sizing.tap(80))
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: Sizing.s(14)) {
            ForEach(ShopCatalog.visibleCategories(owned: progress.purchasedShopItemIds), id: \.self) { tab in
                SoundButton {
                    category = tab
                } label: {
                    Text(Self.title(of: tab))
                        .frame(maxWidth: .infinity)
                        .frame(height: Sizing.tap(60))
                        .background(category == tab ? Color.darkGreen : Color.white)
                        .foregroundColor(category == tab ? .white : Color.darkGreen)
                        .cornerRadius(Sizing.s(20))
                        .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
                }
            }
        }
    }

    private static func title(of category: ShopCategory) -> LocalizedStringKey {
        switch category {
        case .keyboard: return "Keyboard"
        case .notes: return "Notes"
        case .outfit: return "Outfit"
        case .boost: return "Boosts"
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
            actionButton(for: item)
        }
        .padding(Sizing.isPhone ? 8 : 16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Sizing.s(28)).fill(Color.white))
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
            let canAfford = progress.coinBalance >= item.price
            SoundButton {
                itemToBuy = item
            } label: {
                HStack(spacing: 8) {
                    AssetImage(name: "icon_coin", fallbackEmoji: "🪙")
                        .frame(width: Sizing.s(30), height: Sizing.s(30))
                    Text("\(item.price)")
                }
                .frame(maxWidth: .infinity)
                .frame(height: Sizing.tap(52))
                .background(canAfford ? Color.yellow : Color.gray.opacity(0.35))
                .foregroundColor(canAfford ? Color.darkGreen : Color.darkGreen.opacity(0.5))
                .cornerRadius(Sizing.s(16))
                .font(.custom("BalooDa-Regular", size: Sizing.f(26)))
            }
            .disabled(!canAfford)
            .accessibilityHint(canAfford ? Text("") : Text("Not enough coins"))
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
