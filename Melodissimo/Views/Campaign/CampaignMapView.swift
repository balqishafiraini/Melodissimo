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

    /// What can cover the map: a story card, or the Tour Complete certificate.
    private enum MapStory: Equatable {
        case card(StoryCard)
        case certificate
    }

    private let panelWidth = screenWidth * 0.9

    var body: some View {
        ZStack {
            Image("map_ocean")
                .resizable(resizingMode: .tile)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
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
                        .padding(.horizontal, (screenWidth - panelWidth) / 2)
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
            // A beat after arriving, so the avatar's hop to the new stage is seen before the story starts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { showNextStory() }
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
            .presentationDetents([.height(480)])
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
        ZStack {
            VStack(spacing: 2) {
                Text("Nusantara Tour")
                    .font(Font.largeTitle)
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
        .padding(.horizontal, 30)
        .padding(.top, 12)
        .padding(.bottom, 8)
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
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [1, 14]))

            ForEach(Array(stages.enumerated()), id: \.element.id) { offset, stage in
                let unlocked = progress.isUnlocked(stage)
                StageNodeView(stage: stage,
                              stars: progress.stageStars(stage.id),
                              isUnlocked: unlocked,
                              isCurrent: stage.id == current.id)
                    .position(points[offset])
                    .onTapGesture {
                        if unlocked { onSelect(stage) }
                    }
            }

            // Alpanica waits on the stage the player is up to and hops over when it changes.
            if current.chapter == chapter.number, let offset = stages.firstIndex(where: { $0.id == current.id }) {
                AlpanicaView(mood: .idle, outfit: .none, hopTrigger: current.id, height: 110)
                    .position(x: points[offset].x, y: points[offset].y - (current.isLandmark ? 118 : 100))
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: current.id)
                    .allowsHitTesting(false)
            }

            header

            if isLocked {
                lockedOverlay
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 40))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: chapter.symbol)
                .font(.custom("BalooDa-Regular", size: 34))
                .foregroundColor(.white)
                .frame(width: 66, height: 66)
                .background(Circle().fill(Color(hex: chapter.tintHex)))
            VStack(alignment: .leading, spacing: 0) {
                Text(chapter.name)
                    .font(.custom("BalooDa-Regular", size: 44))
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
        .padding(24)
    }

    /// Dims a chapter that hasn't been reached and says how to sail there.
    private var lockedOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
            VStack(spacing: 10) {
                Text("🔒")
                    .font(.custom("BalooDa-Regular", size: 80))
                if chapter.number > 1 {
                    Text("Clear \(CampaignCatalog.chapter(chapter.number - 1).bossSongTitle) to sail here")
                        .font(.custom("BalooDa-Regular", size: 30))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
    }
}
