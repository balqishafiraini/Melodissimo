//
//  AchievementsView.swift
//  Melodissimo
//
//  Shows the player's daily streak and the list of earned / locked badges.
//

import SwiftUI
import Foundation

struct AchievementsView: View {
    @ObservedObject private var store = AchievementStore.shared
    @ObservedObject private var progress = ProgressStore.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.darkGreen.ignoresSafeArea()

            VStack {
                ZStack {
                    Text("Achievements")
                        .font(.largeTitle)
                        .foregroundColor(.white)

                    HStack {
                        SoundButton {
                            dismiss()
                        } label: {
                            Text("< Back")
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .frame(minWidth: Sizing.tap(120), minHeight: Sizing.tap(60), maxHeight: Sizing.tap(60))
                                .background(Color.yellow)
                                .foregroundColor(Color.darkGreen)
                                .cornerRadius(Sizing.s(20))
                                .font(Font.headline)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(progress.currentStreak) days")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(.horizontal, Sizing.s(20))
                        .frame(height: Sizing.tap(60))
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                    }
                }
                .padding(.all, Sizing.isPhone ? 8 : nil)

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: Sizing.isPhone ? 280 : 320), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(store.achievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                    .padding(.all, Sizing.isPhone ? 8 : nil)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            store.reload()
        }
    }
}

private struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: achievement.systemImage)
                .font(.largeTitle)
                .foregroundColor(achievement.isEarned ? .yellow : .white.opacity(0.3))
                .frame(width: Sizing.s(60))

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.title3)
                    .bold()
                    .foregroundColor(achievement.isEarned ? .white : .white.opacity(0.5))
                Text(achievement.detail)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            if achievement.isEarned {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(achievement.isEarned ? 0.15 : 0.05))
        )
    }
}
