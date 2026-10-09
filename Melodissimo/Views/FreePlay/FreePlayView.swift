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
    @State private var isChoosingEchoLevel = false

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
                        HubCard(title: "Songs", subtitle: "Pick any of the 18 songs", icon: "icon_stage_song") {
                            router.push(.songRepositoryQuiz)
                        }
                        HubCard(title: "Classic Levels", subtitle: "The 100 note-reading levels", icon: "icon_stage_battle") {
                            router.push(.notationLevelMenu)
                        }
                    }
                    GridRow {
                        HubCard(title: "Echo", subtitle: echoSubtitle, icon: "icon_stage_echo") {
                            isChoosingEchoLevel = true
                        }
                        HubCard(title: "Melody Rush", subtitle: rushSubtitle, icon: "icon_stage_boss") {
                            router.push(.play(PlayRequest(kind: .rush)))
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(30)
        }
        .confirmationDialog("Echo", isPresented: $isChoosingEchoLevel, titleVisibility: .visible) {
            Button("Easy: the keys light up") { startEcho(glow: true) }
            Button("Hard: listen only") { startEcho(glow: false) }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// An endless Echo run over the middle notes (1 2 3 4 5 6 7 1˙); later rounds use phrases from real songs.
    /// `PlayDestinationView` gives it a fresh seed every time.
    private func startEcho(glow: Bool) {
        let config = EchoConfig(pool: Array(5...12), roundsToClear: nil, startLength: 2, maxLength: 8,
                                glowDuringPlayback: glow, useSongSnippets: true, seed: 0)
        router.push(.play(PlayRequest(kind: .echo(config))))
    }

    private var echoSubtitle: LocalizedStringKey {
        progress.echoHighScore > 0 ? "Best \(progress.echoHighScore) rounds" : "Hear it, play it back"
    }

    private var rushSubtitle: LocalizedStringKey {
        progress.rushHighScore > 0 ? "High score \(progress.rushHighScore)" : "How far can you go?"
    }
}
