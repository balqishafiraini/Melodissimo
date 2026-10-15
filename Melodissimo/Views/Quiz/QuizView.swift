//
//  QuizView.swift
//  Melodissimo
//

import SwiftUI

/// The listening quizzes: a few notes play, the player taps an answer. Guess the Song shows four
/// titles, Spot Fals's note shows the phrase as written in *not angka* (tap the note that sounded
/// wrong), Higher or lower shows three big buttons.
struct QuizView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: QuizViewModel

    /// The request this came from, so the results screen can offer Retry.
    let request: PlayRequest

    @State private var mood: AlpanicaMood = .idle
    @State private var moodToken = 0
    @State private var isOnScreen = true
    @State private var hasFinished = false

    init(request: PlayRequest, config: QuizConfig) {
        self.request = request
        _viewModel = StateObject(wrappedValue: QuizViewModel(config: config))
    }

    private var variant: QuizVariant { viewModel.config.variant }

    var body: some View {
        ZStack {
            ScreenBackdrop(color: Color.softBlue, overlaysColor: true)

            VStack(spacing: Sizing.s(16)) {
                topBar
                statusPanel
                choices
                    .padding(.horizontal, Sizing.s(24))
                    .padding(.bottom, Sizing.s(24))
            }
        }
        .playScreen()
        .task {
            while !Task.isCancelled {
                await MainActor.run {
                    if isOnScreen { viewModel.step(now: CACurrentMediaTime()) }
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AudioSessionController.didInterrupt)) { _ in
            viewModel.silence()
        }
        .onChange(of: viewModel.phase) { phase in
            switch phase {
            case .feedback(_, let isCorrect):
                if isCorrect {
                    setMood(.happy, for: 0.9)
                    SFX.play(.star)
                } else {
                    setMood(.sad, for: 1.2)
                    SFX.play(.wrong)
                }
            case .won, .lost:
                finish()
            default:
                break
            }
        }
        .onAppear {
            isOnScreen = true
            viewModel.start(now: CACurrentMediaTime())
        }
        .onDisappear {
            isOnScreen = false
            viewModel.silence()
        }
    }

    private func leave() {
        isOnScreen = false
        viewModel.silence()
        router.pop()
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: Sizing.s(20)) {
            SoundButton {
                leave()
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

            Spacer()

            HStack(spacing: 8) {
                Text("Question")
                    .font(.subheadline)
                Text("\(min(viewModel.questionIndex + 1, viewModel.questions.count))/\(viewModel.questions.count)")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(36)))
            }
            .foregroundColor(Color.darkGreen)
        }
        .padding(.horizontal, Sizing.s(24))
        .padding(.top, Sizing.s(8))
        .frame(height: Sizing.isPhone ? 52 : 80)
    }

    /// Alpanica (or Fals, for his quiz), the prompt and the replay button.
    private var statusPanel: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: Sizing.s(32)) {
                Group {
                    if variant == .spotFals {
                        MonsterSprite(kind: 1, isBoss: false, health: nil,
                                      hitTrigger: viewModel.correctCount, lungeTrigger: viewModel.hearts,
                                      height: min(220, geo.size.height * 0.85))
                    } else {
                        AlpanicaView(mood: alpanicaMood, outfit: .equipped, hopTrigger: viewModel.correctCount,
                                     height: min(220, geo.size.height * 0.9))
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: Sizing.s(12)) {
                    Text(statusText)
                        .font(.custom("BalooDa-Regular", size: Sizing.f(44)))
                        .foregroundColor(Color.darkGreen)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                    replayButton
                }
                .frame(maxWidth: .infinity)

                Color.clear.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Sizing.s(24))
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var alpanicaMood: AlpanicaMood {
        if mood == .idle, case .listening = viewModel.phase { return .think }
        return mood
    }

    private var statusText: LocalizedStringKey {
        switch viewModel.phase {
        case .ready, .listening:
            return "👂 Listen…"
        case .answering:
            switch variant {
            case .guessSong: return "Which song is it?"
            case .spotFals: return "Fals changed one note! Which one?"
            case .higherLower: return "Was the second note higher or lower?"
            }
        case .feedback(_, let isCorrect):
            return isCorrect ? "⭐ Correct!" : "Oops! Here's the right one"
        case .won:
            return "You did it!"
        case .lost:
            return "Out of hearts"
        }
    }

    private var replayButton: some View {
        SoundButton {
            viewModel.replay(now: CACurrentMediaTime())
        } label: {
            Label("Play again", systemImage: "speaker.wave.2.fill")
                .lineLimit(1)
                .padding(.horizontal, Sizing.s(20))
                .frame(minHeight: Sizing.tap(56))
                .background(Color.white)
                .foregroundColor(Color.darkGreen)
                .cornerRadius(Sizing.s(18))
                .font(Font.headline)
        }
        .disabled(!viewModel.canReplay)
        .opacity(viewModel.canReplay ? 1 : 0.5)
    }

    // MARK: Choices

    @ViewBuilder
    private var choices: some View {
        if let question = viewModel.question {
            switch variant {
            case .guessSong:
                Grid(horizontalSpacing: Sizing.s(16), verticalSpacing: Sizing.s(16)) {
                    ForEach(Array(stride(from: 0, to: question.choices.count, by: 2)), id: \.self) { row in
                        GridRow {
                            ForEach(row..<min(row + 2, question.choices.count), id: \.self) { index in
                                choiceButton(index, in: question, font: .custom("BalooDa-Regular", size: Sizing.f(30)))
                            }
                        }
                    }
                }
            case .spotFals:
                HStack(spacing: Sizing.s(12)) {
                    ForEach(question.choices.indices, id: \.self) { index in
                        choiceButton(index, in: question, font: .custom("BalooDa-Regular", size: Sizing.f(56)))
                    }
                }
            case .higherLower:
                HStack(spacing: Sizing.s(16)) {
                    ForEach(question.choices.indices, id: \.self) { index in
                        choiceButton(index, in: question, font: .custom("BalooDa-Regular", size: Sizing.f(40)),
                                     icon: ["arrow.up", "arrow.down", "equal"][index])
                    }
                }
            }
        }
    }

    private func choiceButton(_ index: Int, in question: QuizQuestion, font: Font, icon: String? = nil) -> some View {
        let style = choiceStyle(index, in: question)
        return SoundButton {
            viewModel.answer(index, now: CACurrentMediaTime())
        } label: {
            VStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .frame(height: Sizing.f(44))
                }
                Text(LocalizedStringKey(question.choices[index]))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
            .font(font)
            .padding(Sizing.s(12))
            .frame(maxWidth: .infinity, minHeight: Sizing.tap(80), maxHeight: Sizing.isPhone ? 90 : 150)
            .background(style.background)
            .foregroundColor(style.foreground)
            .cornerRadius(Sizing.s(24))
        }
        .disabled(!viewModel.canAnswer)
    }

    /// Green on the right answer and red on a wrong pick once answered; during playback in Spot Fals
    /// the written note that is sounding is lit, so the player can follow along.
    private func choiceStyle(_ index: Int, in question: QuizQuestion) -> (background: Color, foreground: Color) {
        switch viewModel.phase {
        case .feedback(let chosen, _):
            if index == question.correctIndex { return (Color.green, .white) }
            if index == chosen { return (Color.red, .white) }
            return (Color.white.opacity(0.6), Color.darkGreen)
        case .listening(let playing) where variant == .spotFals && playing == index:
            return (Color.yellow, Color.darkGreen)
        default:
            return (Color.white, Color.darkGreen)
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

    // MARK: Finish

    /// Records the result once (the score is the number of right answers) and shows the results screen after a beat.
    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        var result = PlayResult(request: request, didWin: viewModel.phase == .won, stars: viewModel.stars,
                                score: viewModel.correctCount, accuracy: nil, maxCombo: viewModel.bestStreak,
                                perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        result.correctCount = viewModel.correctCount
        let rewards = ResultRecorder.record(result)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if isOnScreen {
                router.replaceTop(with: .result(result, rewards))
            }
        }
    }
}

extension QuizVariant {
    var title: LocalizedStringKey {
        switch self {
        case .guessSong: return "Guess the Song"
        case .spotFals: return "Spot Fals's Note"
        case .higherLower: return "Higher or Lower?"
        }
    }
}
