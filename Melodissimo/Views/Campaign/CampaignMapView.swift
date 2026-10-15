//
//  CampaignMapView.swift
//  Melodissimo
//

import SwiftUI

/// The Nusantara Tour: six island panels side by side on an ocean. Each shows its stage nodes along
/// a dashed zig-zag path; Alpanica stands on the stage the player is up to.
struct CampaignMapView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var progress = ProgressStore.shared
    @State private var selectedStage: Stage?
    /// The story card or certificate currently covering the map.
    @State private var story: MapStory?
    /// False once the player has left, so a pending card doesn't pop up behind another screen.
    @State private var isOnScreen = true
    /// The stage the player was up to when the map last appeared, to tell when a new one has opened.
    @State private var lastSeenStageId: String?

    /// What can cover the map: a story card, or the Tour Complete certificate.
    private enum MapStory: Equatable {
        case card(StoryCard)
        case certificate
    }

    /// How wide an island panel is on iPhone. An island's art is 1000 × 600, so the panel is as wide as the room under
    /// the title bar allows (but never wider than the width it has). On iPad it is `screenWidth * 0.9`, as ever.
    private func phonePanelWidth(in area: CGSize) -> CGFloat {
        max(240, min(area.width * 0.92, (area.height - 8) / 0.6))
    }

    var body: some View {
        ZStack {
            Image("map_ocean")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if Sizing.isPhone {
                    GeometryReader { area in
                        let width = phonePanelWidth(in: area.size)
                        islands(panelWidth: width, sidePadding: (area.size.width - width) / 2)
                    }
                } else {
                    // iPad: no GeometryReader, so the layout (including where it overflows on the smallest iPad) stays as it was.
                    islands(panelWidth: screenWidth * 0.9, sidePadding: (screenWidth - screenWidth * 0.9) / 2)
                }
            }
        }
        .overlay {
            if let story {
                storyView(story)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: story)
        .onAppear {
            isOnScreen = true
            // The avatar hops to a stage that has just opened: a little fanfare as it lands.
            let currentId = progress.currentStage.id
            if let last = lastSeenStageId, last != currentId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { if isOnScreen { SFX.play(.unlock) } }
            }
            lastSeenStageId = currentId
            // A beat after arriving, so the avatar's hop to the new stage is seen before the story starts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { showNextStory() }
            #if DEBUG
            // `-qaOverlay story|storyBoss|certificate`: open that overlay for the screenshot scripts.
            // `-qaOverlay stageSheet|stageSheetBoss` opens the stage sheet of the current / the first boss stage.
            if QARoutes.overlay == "stageSheet" || QARoutes.overlay == "stageSheetBoss" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    if QARoutes.overlay == "stageSheetBoss" {
                        selectedStage = CampaignCatalog.allStages.first { if case .boss = $0.kind { return true } else { return false } }
                    } else {
                        selectedStage = progress.currentStage
                    }
                }
            }
            if let overlay = QARoutes.mapOverlay() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if let card = overlay.card { story = .card(card) } else if overlay.certificate { story = .certificate }
                }
            }
            #endif
        }
        .onDisappear { isOnScreen = false }
        .sheet(item: $selectedStage) { stage in
            StageSheetView(stage: stage,
                           stars: progress.stageStars(stage.id),
                           onPlay: {
                               selectedStage = nil
                               // Let the sheet finish closing before the next screen is pushed.
                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { play(stage) }
                           },
                           onCertificate: showsCertificate(for: stage) ? {
                               selectedStage = nil
                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { story = .certificate }
                           } : nil)
            // iPad: a 480 pt card. iPhone landscape ignores detents and gives an almost full-height sheet.
            .presentationDetents(Sizing.isPhone ? [.large] : [.height(480)])
        }
    }

    /// The six island panels side by side, scrolled to the one the player is up to.
    private func islands(panelWidth: CGFloat, sidePadding: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sizing.s(20)) {
                    ForEach(CampaignCatalog.chapters) { chapter in
                        ChapterPanel(chapter: chapter,
                                     stages: CampaignCatalog.stages(inChapter: chapter.number),
                                     width: panelWidth,
                                     current: progress.currentStage,
                                     progress: progress,
                                     onSelect: { selectedStage = $0 })
                            .id(chapter.number)
                    }
                }
                .padding(.horizontal, sidePadding)
                .frame(maxHeight: .infinity)
            }
            .onAppear {
                // Bring the island the player is up to into view.
                let chapter = progress.currentStage.chapter
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(chapter, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: Story

    @ViewBuilder
    private func storyView(_ story: MapStory) -> some View {
        switch story {
        case .card(let card):
            StoryCardView(card: card) {
                progress.markStorySeen(card.id)
                self.story = nil
                // More cards may be waiting: a boss card is followed by the next island's first card.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showNextStory() }
            }
        case .certificate:
            CertificateView(progress: progress) {
                progress.markStorySeen(StoryCatalog.certificateId)
                self.story = nil
            }
        }
    }

    /// Shows the next unseen story card, then the certificate once every card has been seen.
    private func showNextStory() {
        guard isOnScreen, story == nil, selectedStage == nil else { return }
        if let card = progress.pendingStoryCards.first {
            story = .card(card)
        } else if progress.isCertificatePending {
            story = .certificate
        }
    }

    private func showsCertificate(for stage: Stage) -> Bool {
        if case .finale = stage.kind { return progress.stageStars(stage.id) >= 1 }
        return false
    }

    // MARK: Pieces

    private var topBar: some View {
        ZStack(alignment: Sizing.isPhone ? .top : .center) {
            VStack(spacing: 2) {
                Text("Nusantara Tour")
                    .font(Font.largeTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color.yellow)
                    Text("\(progress.tourStars) / \(CampaignCatalog.allStages.count * 3)")
                        .foregroundColor(.white)
                        .font(Font.title3)
                }
            }

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
        .padding(.horizontal, Sizing.isPhone ? Sizing.topBarSide : Sizing.s(30))
        .padding(.top, Sizing.isPhone ? Sizing.topBarInset : Sizing.s(12))
        .padding(.bottom, Sizing.s(8))
    }

    // MARK: Playing a stage

    /// Opens the right screen for a stage, remembering which stage it was so the result comes back to the map.
    private func play(_ stage: Stage) {
        switch stage.kind {
        case .battle(let config):
            router.push(.play(PlayRequest(kind: .battle(config), campaignStageId: stage.id)))
        case .echo(let config):
            router.push(.play(PlayRequest(kind: .echo(config), campaignStageId: stage.id)))
        case .song(let songId), .finale(let songId):
            router.push(.stageSetup(songId: songId, campaignStageId: stage.id, isBoss: false))
        case .boss(let songId):
            router.push(.stageSetup(songId: songId, campaignStageId: stage.id, isBoss: true))
        }
    }
}

// MARK: - One island

private struct ChapterPanel: View {
    let chapter: Chapter
    let stages: [Stage]
    let width: CGFloat
    let current: Stage
    let progress: ProgressStore
    let onSelect: (Stage) -> Void

    /// The island art is 1000 × 600.
    private var height: CGFloat { width * 0.6 }

    private var isLocked: Bool {
        guard let first = stages.first else { return false }
        return !progress.isUnlocked(first)
    }

    private var earnedStars: Int { progress.chapterStars(chapter.number) }

    var body: some View {
        let points = MapLayout.points(count: stages.count, in: CGSize(width: width, height: height))

        ZStack(alignment: .topLeading) {
            AssetImage(name: "map_island_\(chapter.number)", fallbackEmoji: "🏝️")
                .frame(width: width, height: height)

            // The dashed trail from stage to stage.
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: Sizing.isPhone ? 3 : 6, lineCap: .round, dash: Sizing.isPhone ? [1, 7] : [1, 14]))

            ForEach(Array(stages.enumerated()), id: \.element.id) { offset, stage in
                let unlocked = progress.isUnlocked(stage)
                StageNodeView(stage: stage,
                              stars: progress.stageStars(stage.id),
                              isUnlocked: unlocked,
                              isCurrent: stage.id == current.id)
                    .phoneTapArea()
                    .position(points[offset])
                    .onTapGesture {
                        if unlocked { onSelect(stage) }
                    }
            }

            // Alpanica waits on the stage the player is up to and hops over when it changes.
            if current.chapter == chapter.number, let offset = stages.firstIndex(where: { $0.id == current.id }) {
                AlpanicaView(mood: .idle, outfit: .equipped, hopTrigger: current.id, height: Sizing.s(110))
                    .position(x: points[offset].x, y: points[offset].y - Sizing.s(current.isLandmark ? 118 : 100))
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: current.id)
                    .allowsHitTesting(false)
            }

            header

            if isLocked {
                lockedOverlay
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Sizing.s(40)))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    private var header: some View {
        HStack(spacing: Sizing.s(14)) {
            Image(systemName: chapter.symbol)
                .font(.custom("BalooDa-Regular", size: Sizing.f(34)))
                .foregroundColor(.white)
                .frame(width: Sizing.s(66), height: Sizing.s(66))
                .background(Circle().fill(Color(hex: chapter.tintHex)))
            VStack(alignment: .leading, spacing: 0) {
                Text(chapter.name)
                    .font(.custom("BalooDa-Regular", size: Sizing.f(44)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2)
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color.yellow)
                    Text("\(earnedStars) / \(stages.count * 3)")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
        }
        .padding(Sizing.s(24))
    }

    /// Dims a chapter that hasn't been reached and says how to sail there.
    private var lockedOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
            VStack(spacing: Sizing.s(10)) {
                Text("🔒")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(80)))
                if chapter.number > 1 {
                    Text("Clear \(CampaignCatalog.chapter(chapter.number - 1).bossSongTitle) to sail here")
                        .font(.custom("BalooDa-Regular", size: Sizing.f(30)))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Sizing.s(40))
                }
            }
        }
    }
}

private extension View {
    /// A stage node is small on iPhone, so its tap area is padded out to the full node plus 8 pt around it (centred on the
    /// node, so the position doesn't move). Must come before `.position`, or the area would be the whole panel.
    /// Nothing on iPad.
    @ViewBuilder
    func phoneTapArea() -> some View {
        if Sizing.isPhone {
            self.padding(8).contentShape(Rectangle())
        } else {
            self
        }
    }
}
