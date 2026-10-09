//
//  FreePlayView.swift
//  Melodissimo
//

import SwiftUI

/// Everything outside the campaign, always open: any song, any of the 100 classic levels, Echo
/// and Melody Rush. Teachers assign specific songs, so nothing here is ever locked behind the tour.
struct FreePlayView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.yellow)
                .ignoresSafeArea()
            Image("bgMusic")
                .scaledToFit()

            VStack(spacing: 24) {
                ZStack {
                    Text("Free Play")
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
                        Button {
                            router.push(.help)
                        } label: {
                            Text("?")
                                .frame(width: 80, height: 80)
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .font(Font.title)
                        }
                    }
                }

                Grid(horizontalSpacing: 24, verticalSpacing: 24) {
                    GridRow {
                        card("Songs", subtitle: "Pick any of the 18 songs", icon: "icon_stage_song") {
                            router.push(.songRepositoryQuiz)
                        }
                        card("Classic Levels", subtitle: "The 100 note-reading levels", icon: "icon_stage_battle") {
                            router.push(.notationLevelMenu)
                        }
                    }
                    GridRow {
                        // Echo opens up with Phase 4.
                        card("Echo", subtitle: "Coming soon", icon: "icon_stage_echo", isEnabled: false) {}
                        card("Melody Rush", subtitle: rushSubtitle, icon: "icon_stage_boss") {
                            router.push(.play(PlayRequest(kind: .rush)))
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(30)
        }
    }

    private var rushSubtitle: LocalizedStringKey {
        progress.rushHighScore > 0 ? "High score \(progress.rushHighScore)" : "How far can you go?"
    }

    private func card(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String,
                      isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 20) {
                AssetImage(name: icon, fallbackEmoji: "🎵")
                    .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("BalooDa-Regular", size: 44))
                    Text(subtitle)
                        .font(.headline)
                        .opacity(0.9)
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 36).fill(isEnabled ? Color.green : Color.gray))
            .opacity(isEnabled ? 1 : 0.7)
        }
        .disabled(!isEnabled)
    }
}
