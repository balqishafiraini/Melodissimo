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

    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    init(request: PlayRequest, config: BattleConfig) {
        self.request = request
        // A stage always shows the same monster: minions 1–3 and bosses 1–6 are picked from the seed.
        self.monsterKind = Int(config.seed % (config.isBoss ? 6 : 3)) + 1
        _viewModel = StateObject(wrappedValue: BattleViewModel(config: config))
    }

    var body: some View {
        ZStack {
            Color.red
                .ignoresSafeArea()
                .overlay {
                    Image("bgMusic")
                        .scaledToFit()
                }

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
            }
            .ignoresSafeArea(edges: .bottom)
            .offset(x: nudge)
        }
        .onReceive(ticker) { _ in
            viewModel.step(now: CACurrentMediaTime())
        }
        .onChange(of: viewModel.lastOutcome) { outcome in
            if let outcome { react(to: outcome) }
        }
        .onChange(of: viewModel.phase) { phase in
            if phase != .playing { finish() }
        }
        .onAppear {
            isOnScreen = true
            viewModel.start(now: CACurrentMediaTime())
        }
        .onDisappear {
            isOnScreen = false
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 20) {
            Button {
                router.pop()
            } label: {
                Text("< Back")
                    .frame(width: 120, height: 64)
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .font(Font.headline)
            }

            HeartsView(hearts: viewModel.hearts, maxHearts: max(viewModel.config.hearts, 3))

            Spacer()

            if viewModel.combo >= 2 {
                HStack(spacing: 8) {
                    Text("Combo")
                        .font(.subheadline)
                    Text("\(viewModel.combo)")
                        .font(.custom("BalooDa-Regular", size: 32))
                }
                .foregroundColor(.white)
            }

            HStack(spacing: 8) {
                Text("Score")
                    .font(.subheadline)
                Text("\(viewModel.score)")
                    .font(.custom("BalooDa-Regular", size: 36))
                    .contentTransition(.numericText())
                    .animation(.default, value: viewModel.score)
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(height: 80)
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
            .padding(.horizontal, 24)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }

    private func questionBubble(height: CGFloat) -> some View {
        VStack(spacing: 10) {
            Text(NoteCatalog.note(viewModel.currentQuestion).label)
                .font(.custom("BalooDa-Regular", size: 70))
                .foregroundColor(Color.darkGreen)
                .frame(minWidth: 150)

            // The time left for this note, draining towards the right.
            TimelineView(.animation) { timeline in
                let _ = timeline.date
                if let fraction = viewModel.timerFraction(now: CACurrentMediaTime()) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.darkGreen.opacity(0.15))
                        Capsule()
                            .fill(fraction > 0.3 ? Color.green : Color.red)
                            .frame(width: 150 * fraction)
                    }
                    .frame(width: 150, height: 12)
                } else {
                    Color.clear.frame(width: 150, height: 12)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(SpeechBubble().fill(Color.white))
        .frame(height: height, alignment: .center)
    }

    // MARK: Reactions

    /// Alpanica and the screen react to each answer: she attacks on a hit and winces on a mistake,
    /// when the right key also sounds so the player hears what it should have been.
    private func react(to outcome: BattleViewModel.Outcome) {
        switch outcome.kind {
        case .correct:
            setMood(.attack, for: 0.6)
        case .wrong, .timeout:
            setMood(.sad, for: 0.8)
            if let key = viewModel.revealKeyId {
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
                                correctCount: viewModel.correctCount)
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
        let tail: CGFloat = 22
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: 34)
        path.move(to: CGPoint(x: body.maxX - 2, y: rect.midY - 18))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: body.maxX - 2, y: rect.midY + 18))
        path.closeSubpath()
        return path
    }
}
