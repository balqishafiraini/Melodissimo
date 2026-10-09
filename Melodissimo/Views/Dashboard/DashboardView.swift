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
        NavigationStack(path: $router.path) {
            VStack(spacing: 20) {
                topBar
                tourCard
                Spacer(minLength: 0)
                HStack(spacing: 20) {
                    HomeCard(title: "Daily Challenge", subtitle: "Coming soon", icon: "icon_stage_boss",
                             fill: Color.vanila, text: Color.darkGreen, isEnabled: false) {}
                    HomeCard(title: "Free Play", subtitle: "Songs, levels, Echo and Rush", icon: "icon_stage_echo",
                             fill: Color.red, text: .white) {
                        router.push(.freePlay)
                    }
                    HomeCard(title: "Learn", subtitle: "Notes, songs and a skill test", icon: "icon_stage_song",
                             fill: Color.yellow, text: Color.darkGreen) {
                        router.push(.learnHub)
                    }
                }
                .frame(height: 210)
            }
            .padding(30)
            .frame(height: UIScreen.main.bounds.height, alignment: .top)
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

    // MARK: Top bar

    /// Streak and coins on the left; achievements, settings, help and share on the right.
    private var topBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(progress.currentStreak)")
                    .foregroundColor(.white)
                    .font(Font.headline)
            }
            .padding(.horizontal, 20)
            .frame(height: 72)
            .background(Capsule().fill(Color.darkGreen))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Day streak"))
            #if DEBUG
            // Developer shortcut: long-press the streak to open the Chart Recorder.
            .onLongPressGesture(minimumDuration: 1) {
                router.push(.chartRecorder)
            }
            #endif

            CoinBadge()
            iconButton("bag.fill", label: "Shop", fill: Color.yellow, tint: Color.darkGreen) {
                router.push(.shop)
            }

            Spacer()

            iconButton("trophy.fill", label: "Achievements", fill: Color.yellow, tint: Color.darkGreen) {
                router.push(.achievements)
            }
            // Placeholder until the settings screen exists (Task 6.4).
            iconButton("gearshape.fill", label: "Settings", fill: Color.darkGreen, tint: .white) {}
                .disabled(true)
                .opacity(0.45)
            iconButton("questionmark", label: "Help", fill: Color.darkGreen, tint: .white) {
                router.push(.help)
            }
            iconButton("square.and.arrow.up", label: "Share", fill: Color.yellow, tint: Color.darkGreen) {
                shareApp()
            }
        }
    }

    private func iconButton(_ symbol: String, label: LocalizedStringKey, fill: Color, tint: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 72, height: 72)
                .background(fill)
                .foregroundColor(tint)
                .cornerRadius(20)
                .font(Font.title2)
        }
        .accessibilityLabel(Text(label))
    }

    /// Opens the system share sheet with the app's invitation text.
    private func shareApp() {
        let shareText = NSLocalizedString("Learn melodica (pianika) in a more fun way with Melodissimo! Download it on the App Store (only available on iPad) https://s.id/GetMelodissimo", comment: "")
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
    }

    // MARK: Nusantara Tour card

    /// The big call to action: which island the player is on, the next stage, and the tour's stars.
    private var tourCard: some View {
        let current = progress.currentStage
        let chapter = CampaignCatalog.chapter(current.chapter)
        return Button {
            router.push(.campaignMap)
        } label: {
            HStack(spacing: 30) {
                AlpanicaView(mood: .idle, outfit: .equipped, hopTrigger: 0, height: 210)
                    .frame(width: 230)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Nusantara Tour")
                        .font(.custom("BalooDa-Regular", size: 52))
                        .foregroundColor(.white)

                    if progress.isTourComplete {
                        Label("Tour Complete", systemImage: "checkmark.seal.fill")
                            .font(.custom("BalooDa-Regular", size: 30))
                            .foregroundColor(Color.yellow)
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: chapter.symbol)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color(hex: chapter.tintHex)))
                                .foregroundColor(.white)
                            Text(chapter.name)
                                .font(.custom("BalooDa-Regular", size: 32))
                                .foregroundColor(.white)
                        }
                        HStack(spacing: 6) {
                            Text("Up next:")
                            Text(current.title)
                        }
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(Color.yellow)
                        Text("\(progress.tourStars) / \(CampaignCatalog.allStages.count * 3)")
                            .foregroundColor(.white)
                    }
                    .font(.title3)
                }

                Spacer(minLength: 0)

                Text(progress.tourStars == 0 ? "Start" : "Continue")
                    .font(.custom("BalooDa-Regular", size: 34))
                    .foregroundColor(Color.darkGreen)
                    .frame(width: 210, height: 76)
                    .background(Capsule().fill(Color.yellow))
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 240, maxHeight: 300)
            .background(RoundedRectangle(cornerRadius: 40).fill(Color.darkGreen))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
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
        case .result(let result, let rewards):
            StageResultView(result: result, rewards: rewards)
        case .freePlay:
            FreePlayView()
        case .campaignMap:
            CampaignMapView()
        case .learnHub:
            LearnHubView()
        case .shop:
            ShopView()
        case .chartRecorder:
            #if DEBUG
            ChartRecorderView()
            #else
            UnavailableModeView()
            #endif
        case .chartPreview(let chart):
            #if DEBUG
            if let song = SongLibrary.song(id: chart.id) {
                SongStageView(song: song, mode: .listen, chart: chart)
            } else {
                UnavailableModeView()
            }
            #else
            UnavailableModeView()
            #endif
        case .stageSetup(let songId, let campaignStageId, let isBoss):
            if let song = SongLibrary.song(id: songId) {
                StageSetupView(song: song, campaignStageId: campaignStageId, isBoss: isBoss)
            } else {
                UnavailableModeView()
            }
        }
    }
}

/// One of the three smaller cards on Home: a badge, a title and a line of detail.
private struct HomeCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let fill: Color
    let text: Color
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                AssetImage(name: icon, fallbackEmoji: "🎵")
                    .frame(width: 84, height: 84)
                    .saturation(isEnabled ? 1 : 0)
                Text(title)
                    .font(.custom("BalooDa-Regular", size: 36))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.subheadline)
                    .lineLimit(2)
                    .opacity(0.9)
            }
            // A card that isn't open yet keeps its solid fill and only fades its contents.
            .foregroundColor(text.opacity(isEnabled ? 1 : 0.55))
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 36).fill(fill))
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .disabled(!isEnabled)
    }
}
