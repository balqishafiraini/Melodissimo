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

    /// Set when the pre-play test has just finished: Home takes the new player straight to the first stage.
    var startsFirstStage = false
    @State private var hasStartedFirstStage = false
    @ObservedObject private var bootstrap = BootstrapService.shared
    @State private var isShowingSoftUpdate = false

    var body: some View {
        NavigationStack(path: $router.path) {
            VStack(spacing: Sizing.s(20)) {
                if let maintenance = bootstrap.maintenance, maintenance.blocksPlay != true {
                    MaintenanceBanner(info: maintenance)
                }
                topBar
                tourCard
                Spacer(minLength: 0)
                HStack(spacing: Sizing.s(20)) {
                    dailyCard
                    HomeCard(title: "Free Play", subtitle: "Songs, levels, Echo and Rush", icon: "icon_stage_echo",
                             fill: Color.red, text: .white) {
                        router.push(.freePlay)
                    }
                    HomeCard(title: "Learn", subtitle: "Notes, songs and a skill test", icon: "icon_stage_song",
                             fill: Color.yellow, text: Color.darkGreen) {
                        router.push(.learnHub)
                    }
                }
                .frame(height: Sizing.isPhone ? 104 : 210)
            }
            .topBarScreenPadding(ipad: 30)
            // iPad: exactly the screen's height, as always. iPhone: whatever the safe area leaves.
            .frame(height: Sizing.isPhone ? nil : screenHeight, alignment: .top)
            .frame(maxHeight: Sizing.isPhone ? .infinity : nil, alignment: .top)
            // Background (not a ZStack child) so the scaledToFill image can't widen the
            // layout past the screen on aspect ratios that differ from the artwork's.
            .background {
                Image("dashboard")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: startFirstStageIfNeeded)
            .onAppear(perform: showSoftUpdateIfDue)
            .onChange(of: bootstrap.directive) { _ in showSoftUpdateIfDue() }
            .sheet(isPresented: $isShowingSoftUpdate) {
                SoftUpdateSheet(info: bootstrap.current?.update) { isShowingSoftUpdate = false }
            }
            .onAppear { GameCenter.shared.authenticate() }
            #if DEBUG
            .onAppear { QARoutes.applyLaunchRoute(to: router) }
            #endif
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .environmentObject(router)
        .playSessionSystemUI()
    }

    // MARK: Soft update

    /// Asks for a recommended update on Home, at most once per recommended build per three days.
    private func showSoftUpdateIfDue() {
        guard bootstrap.directive == .soft, let recommended = bootstrap.current?.update?.policy?.recommendedBuild else { return }
        let key = UpdateGate.softKey(recommendedBuild: recommended)
        let last = UserDefaults.standard.object(forKey: key) as? Date
        guard UpdateGate.shouldShowSoft(lastShown: last, now: Date()) else { return }
        UserDefaults.standard.set(Date(), forKey: key)
        isShowingSoftUpdate = true
    }

    // MARK: First stage

    /// After the pre-play test a new player lands on stage `c1-01` (with the map underneath, so Next and
    /// Back lead somewhere sensible), where three coach-mark bubbles explain the screen.
    private func startFirstStageIfNeeded() {
        guard startsFirstStage, !hasStartedFirstStage else { return }
        hasStartedFirstStage = true
        guard progress.tourStars == 0, !progress.isCoachSeen(CoachMarks.seenId),
              let stage = CampaignCatalog.stage(id: CoachMarks.firstStageId),
              case .battle(let config) = stage.kind else { return }
        // A beat after arriving, so Home is seen to open before the stage slides in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            router.push(.campaignMap)
            router.push(.play(PlayRequest(kind: .battle(config), campaignStageId: stage.id)))
        }
    }

    // MARK: Top bar

    /// Streak and coins on the left; achievements, settings, help and share on the right.
    private var topBar: some View {
        HStack(spacing: Sizing.s(14)) {
            HStack(spacing: Sizing.s(8)) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(progress.currentStreak)")
                    .foregroundColor(.white)
                    .font(Font.headline)
            }
            .padding(.horizontal, Sizing.s(20))
            .frame(height: Sizing.tap(72))
            .background(Capsule().fill(Color.darkGreen))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Day streak"))
            #if DEBUG
            // Developer shortcut: long-press the streak to open the Chart Recorder.
            .onLongPressGesture(minimumDuration: 1) {
                router.push(.chartRecorder)
            }
            #endif

            SoundButton {
                router.push(.shopCoins)
            } label: {
                CoinBadge()
            }
            iconButton("bag.fill", label: "Shop", fill: Color.yellow, tint: Color.darkGreen) {
                router.push(.shop)
            }

            Spacer()

            iconButton("trophy.fill", label: "Achievements", fill: Color.yellow, tint: Color.darkGreen) {
                router.push(.achievements)
            }
            iconButton("gearshape.fill", label: "Settings", fill: Color.darkGreen, tint: .white) {
                router.push(.settings)
            }
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
        SoundButton(action: action) {
            Image(systemName: symbol)
                .frame(width: Sizing.tap(72), height: Sizing.tap(72))
                .background(fill)
                .foregroundColor(tint)
                .cornerRadius(Sizing.s(20))
                .font(Font.title2)
        }
        .accessibilityLabel(Text(label))
    }

    /// Opens the system share sheet with the app's invitation text.
    private func shareApp() {
        let shareText = NSLocalizedString("Learn melodica (pianika) in a more fun way with Melodissimo! Download it on the App Store (iPhone & iPad) https://s.id/GetMelodissimo", comment: "")
        // Finding the key window scene
        if let keyWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            // Accessing the key window from the window scene
            if let rootViewController = keyWindowScene.windows.first?.rootViewController {
                let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)

                // Adjust popover presentation on iPad
                activityViewController.popoverPresentationController?.sourceView = rootViewController.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: screenWidth / 2, y: screenHeight / 2, width: 0, height: 0)

                // Presenting the share sheet
                rootViewController.present(activityViewController, animated: true, completion: nil)
            }
        }
    }

    // MARK: Daily challenge

    /// Today's challenge: its type and reward, or a tick once it has been won.
    private var dailyCard: some View {
        let challenge = DailyChallenge.make(for: Date(), chapter: progress.currentStage.chapter)
        let isDone = challenge.map { progress.isDailyDone($0.dateKey) } ?? false
        let reward = CoinRewards.daily(streak: progress.streakAfterPlayingToday())
        let subtitle: LocalizedStringKey
        switch (challenge?.kind, isDone) {
        case (nil, _): subtitle = "Coming soon"
        case (_, true): subtitle = "Done! Come back tomorrow"
        case (.echo?, false): subtitle = "Echo · +\(reward) coins"
        case (.battle?, false): subtitle = "Note Battle · +\(reward) coins"
        case (.songSprint?, false): subtitle = "Song Sprint · +\(reward) coins"
        }
        return HomeCard(title: "Daily Challenge", subtitle: subtitle, icon: "icon_stage_boss",
                        fill: Color.vanila, text: Color.darkGreen, isEnabled: challenge != nil, isDone: isDone) {
            // The date is read again at the tap, in case the app has been open past midnight.
            let key = DailyChallenge.dateKey(for: Date())
            router.push(.play(PlayRequest(kind: .daily(dateKey: key))))
        }
    }

    // MARK: Nusantara Tour card

    /// The big call to action: which island the player is on, the next stage, and the tour's stars.
    private var tourCard: some View {
        let current = progress.currentStage
        let chapter = CampaignCatalog.chapter(current.chapter)
        return SoundButton {
            router.push(.campaignMap)
        } label: {
            HStack(spacing: Sizing.s(30)) {
                AlpanicaView(mood: .idle, outfit: .equipped, hopTrigger: 0, height: Sizing.s(210), fidgets: true)
                    .frame(width: Sizing.s(230))

                VStack(alignment: .leading, spacing: Sizing.isPhone ? 2 : 10) {
                    Text("Nusantara Tour")
                        .font(.custom("BalooDa-Regular", size: Sizing.isPhone ? 30 : 52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundColor(.white)

                    if progress.isTourComplete {
                        Label("Tour Complete", systemImage: "checkmark.seal.fill")
                            .font(.custom("BalooDa-Regular", size: Sizing.f(30)))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundColor(Color.yellow)
                    } else {
                        HStack(spacing: Sizing.s(10)) {
                            Image(systemName: chapter.symbol)
                                .frame(width: Sizing.tap(44), height: Sizing.tap(44))
                                .background(Circle().fill(Color(hex: chapter.tintHex)))
                                .foregroundColor(.white)
                            Text(chapter.name)
                                .font(.custom("BalooDa-Regular", size: Sizing.f(32)))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .foregroundColor(.white)
                        }
                        HStack(spacing: 6) {
                            Text("Up next:")
                            Text(current.title)
                        }
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundColor(.white.opacity(0.9))
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(Color.yellow)
                        Text("\(progress.tourStars) / \(CampaignCatalog.allStages.count * 3)")
                            .lineLimit(1)
                            .foregroundColor(.white)
                    }
                    .font(.title3)
                }

                Spacer(minLength: 0)

                Text(progress.tourStars == 0 ? "Start" : "Continue")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(34)))
                    .foregroundColor(Color.darkGreen)
                    .buttonFrame(width: 210, height: 76)
                    .background(Capsule().fill(Color.yellow))
            }
            .padding(.horizontal, Sizing.s(36))
            .frame(maxWidth: .infinity)
            .frame(minHeight: Sizing.isPhone ? 140 : 240, maxHeight: Sizing.isPhone ? 190 : 300)
            .background(RoundedRectangle(cornerRadius: Sizing.s(40)).fill(Color.darkGreen))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
    }

    /// Maps each route to its screen. Centralised so there is a single source of
    /// truth for the game flow's navigation.
    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .notationLearn:
            NotationLearnView()
        case .songRepositoryLearn:
            SongRepositoryLearnView()
        case .songLearn(let songTitle):
            SongLearnView(songTitle: songTitle)
        case .notationLevelMenu:
            NotationQuizLevelMenuView()
        case .songRepositoryQuiz:
            SongRepositoryQuizView()
        case .help:
            HelpPageView()
        case .achievements:
            AchievementsView()
        case .postplay:
            // iPhone: one self-contained screen (a NavigationView inside this stack does not work there).
            if Sizing.isPhone { PhoneSkillTestView() } else { OnboardPostplayView() }
        case .play(let request):
            // `replaceTop` from one play to another (Practice → Perform) keeps the same stack slot, so without a
            // per-request identity SwiftUI reuses the old screen and its finished engine.
            PlayDestinationView(request: request)
                .id(request)
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
        case .shopCoins:
            ShopView(startAtCoins: true)
        case .settings:
            SettingsView()
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
    /// A tick on the badge, for a daily challenge that has been won.
    var isDone = false
    let action: () -> Void

    var body: some View {
        SoundButton(action: action) {
            // iPad: the badge above the words. iPhone has too little height for that, so the badge sits beside them.
            if Sizing.isPhone {
                HStack(spacing: 8) {
                    badge
                    VStack(alignment: .leading, spacing: 0) {
                        titleText
                        subtitleText
                    }
                    // A Button centres its label's text by default; the phone card reads left to right.
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .foregroundColor(text.opacity(isEnabled ? 1 : 0.55))
                .padding(Sizing.s(22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Sizing.s(36)).fill(fill))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            } else {
                VStack(alignment: .leading, spacing: Sizing.s(6)) {
                    badge
                    titleText
                    subtitleText
                }
                // A card that isn't open yet keeps its solid fill and only fades its contents.
                .foregroundColor(text.opacity(isEnabled ? 1 : 0.55))
                .padding(Sizing.s(22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: Sizing.s(36)).fill(fill))
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            }
        }
        .disabled(!isEnabled)
    }
    private var badge: some View {
        AssetImage(name: icon, fallbackEmoji: "🎵")
            .frame(width: Sizing.s(84), height: Sizing.s(84))
            .saturation(isEnabled ? 1 : 0)
            .overlay(alignment: .topTrailing) {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                        .background(Circle().fill(Color.white))
                        .offset(x: Sizing.s(10), y: -Sizing.s(6))
                }
            }
    }

    private var titleText: some View {
        Text(title)
            .font(.custom("BalooDa-Regular", size: Sizing.f(36)))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.subheadline)
            .lineLimit(2)
            .minimumScaleFactor(Sizing.isPhone ? 0.8 : 1)
            .opacity(0.9)
    }
}
