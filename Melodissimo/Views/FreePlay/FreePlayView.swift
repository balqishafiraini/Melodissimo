//
//  FreePlayView.swift
//  Melodissimo
//

import SwiftUI

/// Everything outside the campaign, always open: any song, any of the 100 classic levels, Echo,
/// Melody Rush and the listening quizzes. Teachers assign specific songs, so nothing here is ever locked behind the tour.
struct FreePlayView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared
    @State private var isChoosingEchoLevel = false
    @State private var isChoosingEarQuiz = false

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.yellow)

            VStack(spacing: Sizing.s(24)) {
                ZStack(alignment: Sizing.isPhone ? .top : .center) {
                    Text("Free Play")
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
                            router.push(.help)
                        } label: {
                            Text("?")
                                .frame(width: Sizing.tap(80), height: Sizing.tap(80))
                                .background(Color.darkGreen)
                                .foregroundColor(.white)
                                .cornerRadius(Sizing.s(20))
                                .font(Font.title)
                        }
                    }
                }

                Grid(horizontalSpacing: Sizing.s(24), verticalSpacing: Sizing.s(24)) {
                    GridRow {
                        HubCard(title: "Songs", subtitle: "Pick any of the \(SongLibrary.all.count) songs", icon: "icon_stage_song") {
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
                    GridRow {
                        HubCard(title: QuizVariant.guessSong.title, subtitle: quizSubtitle(.guessSong, fresh: "Hear the opening, name the song"),
                                icon: "icon_stage_song", color: .orange) {
                            startQuiz(.guessSong)
                        }
                        HubCard(title: "Ear Quiz", subtitle: "Spot Fals's note, or higher or lower?",
                                icon: "icon_stage_echo", color: .orange) {
                            isChoosingEarQuiz = true
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .topBarScreenPadding(ipad: 30)
        }
        .confirmationDialog("Echo", isPresented: $isChoosingEchoLevel, titleVisibility: .visible) {
            Button("Easy: the keys light up") { startEcho(glow: true) }
            Button("Hard: listen only") { startEcho(glow: false) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Ear Quiz", isPresented: $isChoosingEarQuiz, titleVisibility: .visible) {
            Button(QuizVariant.spotFals.title) { startQuiz(.spotFals) }
            Button(QuizVariant.higherLower.title) { startQuiz(.higherLower) }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Ten questions, three hearts. `PlayDestinationView` gives every run a fresh seed.
    private func startQuiz(_ variant: QuizVariant) {
        router.push(.play(PlayRequest(kind: .quiz(QuizConfig(variant: variant, seed: 0)))))
    }

    private func quizSubtitle(_ variant: QuizVariant, fresh: LocalizedStringKey) -> LocalizedStringKey {
        progress.quizBest(variant) > 0 ? "Best \(progress.quizBest(variant))/10" : fresh
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
