//
//  DashboardView.swift
//  Melodissimo
//
//  Created by Balqis on 11/10/23.
//

import SwiftUI

struct DashboardView: View {

    @StateObject private var router = AppRouter()
    @ObservedObject private var progress = ProgressStore.shared

    var body: some View {
        let shareText = NSLocalizedString("Learn melodica (pianika) in a more fun way with Melodissimo! Download it on the App Store (only available on iPad) https://s.id/GetMelodissimo", comment: "")

        NavigationStack(path: $router.path) {
            VStack (alignment: .leading, spacing: 1){
                HStack{
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(progress.currentStreak)")
                            .foregroundColor(.white)
                            .font(Font.headline)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 80)
                    .background(Capsule().fill(Color.darkGreen))

                    Spacer()

                    Button {
                        router.push(.achievements)
                    } label: {
                        Image(systemName: "trophy.fill")
                            .frame(width: 80, height: 80)
                            .background(Color.yellow)
                            .foregroundColor(Color.darkGreen)
                            .cornerRadius(20)
                            .font(Font.title)
                    }
                    .padding(.trailing)

                    Button {
                        // Finding the key window scene
                        if let keyWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            // Accessing the key window from the window scene
                            if let rootViewController = keyWindowScene.windows.first?.rootViewController {
                                let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)

                                // Adjust popover presentation on iPad
                                activityViewController.popoverPresentationController?.sourceView = rootViewController.view
                                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)

                                // Presenting the share sheet
                                rootViewController.present(activityViewController, animated: true, completion: nil)
                            }
                        }
                    } label: {
                        Text("Share")
                            .frame(width: 200, height: 80)
                            .background(Color.yellow)
                            .foregroundColor(Color.darkGreen)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }
                    .padding(.trailing)

                    Button {
                        router.push(.help)
                    } label: {
                        Text("Help")
                            .frame(width: 150, height: 80)
                            .background(Color.darkGreen)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .font(Font.headline)
                    }
                }
                .padding(.bottom)
                Text("Hello! What do you want to learn today?")
                    .font(.largeTitle)
                    .foregroundColor(.white)

                #if DEBUG
                // TEMPORARY (Task 2.1, removed in Task 2.4): open a song's stage setup directly.
                Button {
                    router.push(.stageSetup(songId: "berkibarlah-benderaku"))
                } label: {
                    Text("DEBUG: Stage setup \"Berkibarlah Benderaku\"")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.yellow))
                        .foregroundColor(Color.darkGreen)
                        .font(.footnote)
                }
                Button {
                    router.push(.stageSetup(songId: "indonesia-raya"))
                } label: {
                    Text("DEBUG: Stage setup \"Indonesia Raya\" (solemn)")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.yellow))
                        .foregroundColor(Color.darkGreen)
                        .font(.footnote)
                }
                #endif

                Spacer()

                HStack{
                    Spacer()

                    Button {
                        router.push(.notationMenu)
                    } label: {
                        Image("notationMenuButton")
                    }

                    Spacer()

                    Button {
                        router.push(.songMenu)
                    } label: {
                        Image("songMenuButton")
                    }

                    Spacer()

                    Button {
                        router.push(.postplay)
                    } label: {
                        Image("postplayMenuButton")
                    }

                    Spacer()
                }
                Spacer()
            }
            .padding()
            .frame(height: UIScreen.main.bounds.height, alignment: .topLeading)
            // Background (not a ZStack child) so the scaledToFill image can't widen the
            // layout past the screen on aspect ratios that differ from the artwork's.
            .background {
                Image("dashboard")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .environmentObject(router)
    }

    /// Maps each route to its screen. Centralised so there is a single source of
    /// truth for the game flow's navigation.
    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .notationMenu:
            NotationMenuView()
        case .songMenu:
            SongMenuView()
        case .notationLearn:
            NotationLearnView()
        case .songRepositoryLearn:
            SongRepositoryLearnView()
        case .songLearn(let songTitle):
            SongLearnView(songTitle: songTitle)
        case .notationLevelMenu:
            NotationQuizLevelMenuView()
        case .notationQuiz(let levelNo):
            NotationQuizView(levelNo: levelNo)
        case .songRepositoryQuiz:
            SongRepositoryQuizView()
        case .songQuiz(let songTitle):
            SongQuizView(songTitle: songTitle)
        case .afterQuiz(let level, let answers, let score):
            AfterQuizView(level: level, userAnswer: answers, userScore: score)
        case .help:
            HelpPageView()
        case .achievements:
            AchievementsView()
        case .postplay:
            OnboardPostplayView()
        case .play(let request):
            PlayDestinationView(request: request)
        case .stageSetup(let songId, let campaignStageId, let isBoss):
            if let song = SongLibrary.song(id: songId) {
                StageSetupView(song: song, campaignStageId: campaignStageId, isBoss: isBoss)
            } else {
                UnavailableModeView()
            }
        }
    }
}
