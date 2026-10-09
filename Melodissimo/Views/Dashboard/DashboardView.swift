//
//  DashboardView.swift
//  Melodissimo
//
//  Created by Balqis on 11/10/23.
//

import SwiftUI

/// Typed destinations for the app's single navigation stack rooted at the dashboard.
/// Carrying payloads here (instead of pushing fresh `NavigationView`s) keeps the
/// game flow on one stack so screens push and pop instead of piling up.
enum Route: Hashable {
    case notationMenu
    case songMenu
    case notationLearn
    case songRepositoryLearn
    case songLearn(songTitle: String)
    case notationLevelMenu
    case notationQuiz(levelNo: Int)
    case songRepositoryQuiz
    case songQuiz(songTitle: String)
    case afterQuiz(level: LevelModel, answers: [Int], score: Int)
    case help
    case achievements
    case postplay
}

/// Drives the app's single `NavigationStack`. Screens push routes and pop back
/// (`pop`, `popToRoot`, `pop(to:)`) instead of stacking new navigation containers.
@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Pops back to the first occurrence of `route`, keeping it on top of the stack.
    /// Falls back to the root if the route isn't currently on the stack.
    func pop(to route: Route) {
        if let index = path.firstIndex(of: route) {
            path.removeSubrange((index + 1)...)
        } else {
            popToRoot()
        }
    }
}

struct DashboardView: View {

    @StateObject private var router = AppRouter()
    @ObservedObject private var progress = ProgressStore.shared

    var body: some View {
        let shareText = NSLocalizedString("Learn melodica (pianika) in a more fun way with Melodissimo! Download it on the App Store (only available on iPad) https://s.id/GetMelodissimo", comment: "")

        NavigationStack(path: $router.path) {
            ZStack{
                Image("dashboard")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

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
        }
    }
}
