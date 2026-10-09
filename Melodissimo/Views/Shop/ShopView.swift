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

    private let columns = [GridItem(.adaptive(minimum: 230), spacing: 20)]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.softBlue)
                .ignoresSafeArea()
            Image("bgMusic")
                .scaledToFit()

            VStack(spacing: 18) {
                topBar
                tabs
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(ShopCatalog.items(in: category)) { item in
                            card(for: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(30)
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
                Button {
                    router.pop()
                } label: {
                    Text("Menu")
                        .frame(width: 120, height: 80)
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .font(Font.headline)
                }
                Spacer()
                CoinBadge(height: 80)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 14) {
            ForEach(ShopCategory.allCases, id: \.self) { tab in
                Button {
                    category = tab
                } label: {
                    Text(Self.title(of: tab))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(category == tab ? Color.darkGreen : Color.white)
                        .foregroundColor(category == tab ? .white : Color.darkGreen)
                        .cornerRadius(20)
                        .font(.custom("BalooDa-Regular", size: 28))
                }
            }
        }
    }

    private static func title(of category: ShopCategory) -> LocalizedStringKey {
        switch category {
        case .keyboard: return "Keyboard"
        case .notes: return "Notes"
        case .outfit: return "Outfit"
        }
    }

    private func card(for item: ShopItem) -> some View {
        VStack(spacing: 10) {
            preview(for: item)
                .frame(height: 130)
            Text(LocalizedStringKey(item.name))
                .font(.custom("BalooDa-Regular", size: 28))
                .foregroundColor(Color.darkGreen)
            actionButton(for: item)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 28).fill(Color.white))
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
            AssetImage(name: AlpanicaOutfit(rawValue: item.variant)?.assetName ?? "alpanica", fallbackEmoji: "🦙")
                .padding(6)
                .frame(width: 190)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.softBlue.opacity(0.6)))
        }
    }

    /// Equipped, Equip or Buy, depending on what the player has done with the item.
    @ViewBuilder
    private func actionButton(for item: ShopItem) -> some View {
        if progress.equippedItem(item.category) == item {
            Label("Equipped", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundColor(Color.green)
                .font(.headline)
        } else if progress.owns(item) {
            Button {
                progress.equip(item)
            } label: {
                Text("Equip")
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .font(.headline)
            }
        } else {
            let canAfford = progress.coinBalance >= item.price
            Button {
                itemToBuy = item
            } label: {
                HStack(spacing: 8) {
                    AssetImage(name: "icon_coin", fallbackEmoji: "🪙")
                        .frame(width: 30, height: 30)
                    Text("\(item.price)")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canAfford ? Color.yellow : Color.gray.opacity(0.35))
                .foregroundColor(canAfford ? Color.darkGreen : Color.darkGreen.opacity(0.5))
                .cornerRadius(16)
                .font(.custom("BalooDa-Regular", size: 26))
            }
            .disabled(!canAfford)
            .accessibilityHint(canAfford ? Text("") : Text("Not enough coins"))
        }
    }

    private func buy(_ item: ShopItem) {
        // Wear a new purchase right away, since that is what people want to see.
        if progress.buy(item) {
            progress.equip(item)
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
