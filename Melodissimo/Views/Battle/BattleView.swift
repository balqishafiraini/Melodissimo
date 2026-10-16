//
//  BattleView.swift
//  Melodissimo
//

import SwiftUI

/// The Note Battle: Fals shouts a note in a speech bubble and the player plays it on the keyboard.
/// A right answer hurts the monster; a wrong one (or running out of time) costs a heart, shows the
/// right key and asks the same note again. Win by emptying the monster's health bar before the hearts run out.
struct BattleView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: BattleViewModel

    /// The request this battle came from, so the results screen can offer Retry.
    let request: PlayRequest
    let monsterKind: Int

    @State private var mood: AlpanicaMood = .idle
    @State private var moodToken = 0
    @State private var nudge: CGFloat = 0
    /// False once the player has left, so a pending hop to the results can't hit the wrong screen.
    @State private var isOnScreen = true
    @State private var hasFinished = false
    /// The first stage's three coach-mark bubbles, shown over the battle before the first question.
    @State private var isCoaching = false

    init(request: PlayRequest, config: BattleConfig) {
        self.request = request
        // A stage always shows the same monster: minions 1–3 and bosses 1–8 are picked from the seed.
        self.monsterKind = Int(config.seed % UInt64(config.isBoss ? CampaignCatalog.chapters.count : 3)) + 1
        _viewModel = StateObject(wrappedValue: BattleViewModel(config: config, reviveRun: ReviveRun.forPlay(request)))
    }

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.red, overlaysColor: true)

            VStack(spacing: 0) {
                topBar
                arena
                PianoKeyboard(metrics: .full,
                              showLabels: false,
                              highlights: viewModel.revealKeyId.map { [$0: Color.green] } ?? [:],
                              onNoteOff: { id, isRelease in
                                  // Answers register on finger lift, so a player can slide to aim.
                                  if isRelease { viewModel.answer(keyId: id, now: CACurrentMediaTime()) }
                              })
                    .coachTarget(.keyboard)
            }
            // The iPad keyboard runs to the bottom edge; on iPhone it stays above the home indicator.
            .ignoresSafeArea(edges: Sizing.isPhone ? [] : .bottom)
            .offset(x: nudge)
        }
        .overlayPreferenceValue(CoachTargetKey.self) { anchors in
            GeometryReader { geo in
                if isCoaching {
                    CoachMarkOverlay(steps: CoachMarks.firstStage,
                                     frames: anchors.mapValues { geo[$0] },
                                     onFinish: finishCoaching)
                }
            }
            // The overlay draws edge to edge, so the frames it is given must be measured from the screen's corner too.
            // (On iPad they have always been measured from the safe area; that is left as it was.)
            .ignoresSafeArea(.all, edges: Sizing.isPhone ? .all : [])
        }
        .overlay {
            if viewModel.phase == .awaitingContinue, let run = viewModel.reviveRun {
                ContinueSheet(options: run.options,
                              onRevive: { viewModel.revive($0, now: CACurrentMediaTime()) },
                              onGiveUp: { viewModel.giveUp() },
                              onNeedCoins: { router.push(.shop) })
            }
        }
        .playScreen()
        .task {
            // Every 50 ms while the screen is up; SwiftUI cancels the task when it goes away. It can still tick once during
            // the exit transition, and a timeout then would sound the revealed key on the next screen.
            while !Task.isCancelled {
                await MainActor.run {
                    if isOnScreen { viewModel.step(now: CACurrentMediaTime()) }
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AudioSessionController.didInterrupt)) { _ in
            // Battle has no pause; a call or Siri just silences the revealed key.
            stopAllSounds()
        }
        .onChange(of: viewModel.lastOutcome) { outcome in
            if let outcome { react(to: outcome) }
        }
        .onChange(of: viewModel.phase) { phase in
            if phase == .won || phase == .lost { finish() }
        }
        .onAppear {
            isOnScreen = true
            // A new player's first stage has no timer, so the question can wait while the bubbles are read.
            isCoaching = viewModel.config.timePerNote == nil
                && CoachMarks.shouldShow(stageId: request.campaignStageId,
                                         stars: ProgressStore.shared.stageStars(CoachMarks.firstStageId),
                                         seen: ProgressStore.shared.isCoachSeen(CoachMarks.seenId))
            viewModel.start(now: CACurrentMediaTime())
        }
        .onDisappear {
            isOnScreen = false
            // The revealed key rings out in full on a mistake; it must not carry over to the next screen.
            if let key = viewModel.revealKeyId {
                stopSound(key: NoteCatalog.note(key).sound)
            }
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: Sizing.s(20)) {
            SoundButton {
                // Off screen first, so nothing sounds during the transition; the navigation then silences any note.
                isOnScreen = false
                router.pop()
            } label: {
                Text("< Back")
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(minWidth: Sizing.tap(120), minHeight: Sizing.tap(64), maxHeight: Sizing.tap(64))
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(Sizing.s(20))
                    .font(Font.headline)
            }

            HeartsView(hearts: viewModel.hearts, maxHearts: max(viewModel.config.hearts, 3))
                .coachTarget(.hearts)

            Spacer()

            if viewModel.combo >= 2 {
                HStack(spacing: 8) {
                    Text("Combo")
                        .font(.subheadline)
                    Text("\(viewModel.combo)")
                        .font(.custom("BalooDa-Regular", size: Sizing.f(32)))
                }
                .foregroundColor(.white)
            }

            HStack(spacing: 8) {
                Text("Score")
                    .font(.subheadline)
                Text("\(viewModel.score)")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(36)))
                    .contentTransition(.numericText())
                    .animation(.default, value: viewModel.score)
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, Sizing.s(24))
        .padding(.top, Sizing.s(8))
        .frame(height: Sizing.isPhone ? 52 : 80)
    }

    /// Alpanica on the left, the question in a speech bubble, the monster on the right.
    private var arena: some View {
        GeometryReader { geo in
            let spriteHeight = min(300, geo.size.height * 0.85)
            HStack(alignment: .bottom, spacing: 0) {
                AlpanicaView(mood: mood, outfit: .equipped, hopTrigger: viewModel.correctCount, height: spriteHeight)
                    .frame(maxWidth: .infinity)

                questionBubble(height: spriteHeight * 0.7)
                    .frame(maxWidth: .infinity)

                MonsterSprite(kind: monsterKind,
                              isBoss: viewModel.config.isBoss,
                              health: viewModel.isEndless ? nil : (viewModel.monsterHP, viewModel.config.totalQuestions),
                              hitTrigger: viewModel.correctCount,
                              lungeTrigger: viewModel.mistakeCount,
                              height: spriteHeight * (viewModel.config.isBoss ? 1 : 0.85))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Sizing.s(24))
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }

    private func questionBubble(height: CGFloat) -> some View {
        VStack(spacing: Sizing.s(10)) {
            Text(NoteCatalog.note(viewModel.currentQuestion).label)
                .font(.custom("BalooDa-Regular", size: Sizing.f(70)))
                .foregroundColor(Color.darkGreen)
                .frame(minWidth: Sizing.s(150))

            // The time left for this note, draining towards the right.
            TimelineView(.animation) { timeline in
                let _ = timeline.date
                if let fraction = viewModel.timerFraction(now: CACurrentMediaTime()) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.darkGreen.opacity(0.15))
                        Capsule()
                            .fill(fraction > 0.3 ? Color.green : Color.red)
                            .frame(width: Sizing.s(150) * fraction)
                    }
                    .frame(width: Sizing.s(150), height: Sizing.s(12))
                } else {
                    Color.clear.frame(width: Sizing.s(150), height: Sizing.s(12))
                }
            }
        }
        .padding(.horizontal, Sizing.s(28))
        .padding(.vertical, Sizing.s(18))
        .background(SpeechBubble().fill(Color.white))
        .coachTarget(.question)
        .frame(height: height, alignment: .center)
    }

    private func finishCoaching() {
        ProgressStore.shared.markCoachSeen(CoachMarks.seenId)
        withAnimation { isCoaching = false }
    }

    // MARK: Reactions

    /// Alpanica and the screen react to each answer: she attacks on a hit and winces on a mistake,
    /// when the right key also sounds so the player hears what it should have been.
    private func react(to outcome: BattleViewModel.Outcome) {
        switch outcome.kind {
        case .correct:
            setMood(.attack, for: 0.6)
            SFX.play(.monsterHit)
        case .wrong, .timeout:
            // Too slow catches her by surprise; a wrong key makes her sad.
            setMood(outcome.kind == .timeout ? .surprised : .sad, for: 0.8)
            SFX.play(.playerHurt)
            if isOnScreen, let key = viewModel.revealKeyId {
                playSound(key: NoteCatalog.note(key).sound)
            }
            nudgeScreen()
        }
    }

    private func setMood(_ newMood: AlpanicaMood, for seconds: Double) {
        mood = newMood
        moodToken += 1
        let token = moodToken
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if moodToken == token { mood = .idle }
        }
    }

    /// A quick 8 pt shake when the player is hurt. Skipped under Reduce Motion.
    private func nudgeScreen() {
        guard !reduceMotion else { return }
        for (index, offset) in [8, -8, 6, -6, 0].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 * Double(index)) {
                withAnimation(.linear(duration: 0.05)) { nudge = CGFloat(offset) }
            }
        }
    }

    // MARK: Finish

    /// Records the result once, then shows the results screen after a beat so the last hit or the
    /// revealed key can be seen.
    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        let won = viewModel.phase == .won
        let result = PlayResult(request: request,
                                didWin: won,
                                stars: viewModel.stars,
                                score: viewModel.score,
                                // For finite battles the first-try percentage rides in `accuracy`
                                // (the classic levels' legacy score); `nil` for endless Melody Rush.
                                accuracy: viewModel.isEndless ? nil : Double(viewModel.firstTryPercent),
                                maxCombo: viewModel.maxCombo,
                                perfect: 0, great: 0, good: 0, miss: 0, wrong: 0,
                                correctCount: viewModel.correctCount,
                                revivesUsed: viewModel.reviveRun?.revivesUsed ?? 0)
        let rewards = ResultRecorder.record(result)
        DispatchQueue.main.asyncAfter(deadline: .now() + (won ? 0.9 : 1.4)) {
            if isOnScreen {
                router.replaceTop(with: .result(result, rewards))
            }
        }
    }
}

/// A rounded speech bubble with a small tail pointing right, at the monster.
private struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = Sizing.s(22)
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: Sizing.s(34))
        path.move(to: CGPoint(x: body.maxX - 2, y: rect.midY - Sizing.s(18)))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: body.maxX - 2, y: rect.midY + Sizing.s(18)))
        path.closeSubpath()
        return path
    }
}
