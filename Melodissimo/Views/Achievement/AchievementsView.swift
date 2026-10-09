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
                        Button {
                            dismiss()
                        } label: {
                            Text("< Back")
                                .frame(width: 120, height: 60)
                                .background(Color.yellow)
                                .foregroundColor(Color.darkGreen)
                                .cornerRadius(20)
                                .font(Font.headline)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(progress.currentStreak) hari")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 60)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                    }
                }
                .padding()

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 320), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(store.achievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                    .padding()
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
                .frame(width: 60)

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
