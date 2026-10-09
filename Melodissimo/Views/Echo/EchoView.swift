//
//  EchoView.swift
//  Melodissimo
//

import SwiftUI

/// Echo, the ear-training mode: listen to a short phrase, then play it back. Keys light up while the
/// phrase plays (Easy) or stay dark (Hard); each right note flashes green and shows its name.
struct EchoView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: EchoViewModel

    /// The request this came from, so the results screen can offer Retry.
    let request: PlayRequest

    /// Key frames in window coordinates, to float a note's name above the key that was just played.
    @State private var keyFrames: [Int: CGRect] = [:]
    @State private var correctFlashKey: Int?
    @State private var wrongFlashKey: Int?
    @State private var mood: AlpanicaMood = .idle
    @State private var moodToken = 0
    @State private var isOnScreen = true
    @State private var hasFinished = false

    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    init(request: PlayRequest, config: EchoConfig) {
        self.request = request
        _viewModel = StateObject(wrappedValue: EchoViewModel(config: config))
    }

    var body: some View {
        ZStack {
            Color.softBlue
                .ignoresSafeArea()
                .overlay {
                    Image("bgMusic")
                        .scaledToFit()
                }

            VStack(spacing: 0) {
                topBar
                statusPanel
                PianoKeyboard(metrics: .full,
                              showLabels: false,
                              highlights: highlights,
                              // Echo answers register the moment a key goes down.
                              onNoteOn: { viewModel.answer(keyId: $0, now: CACurrentMediaTime()) },
                              onKeyFrames: { frames in
                                  if frames != keyFrames { keyFrames = frames }
                              })
            }
            .ignoresSafeArea(edges: .bottom)

            nameOverlay
        }
        .onReceive(ticker) { _ in
            viewModel.step(now: CACurrentMediaTime())
        }
        .onChange(of: viewModel.lastOutcome) { outcome in
            if let outcome { react(to: outcome) }
        }
        .onChange(of: viewModel.roundsCleared) { _ in
            setMood(.happy, for: 0.9)
        }
        .onChange(of: viewModel.phase) { phase in
            if phase == .won || phase == .lost { finish() }
        }
        .onAppear {
            isOnScreen = true
            viewModel.start(now: CACurrentMediaTime())
        }
        .onDisappear {
            isOnScreen = false
        }
    }

    // MARK: Keyboard state

    /// The playback glow (yellow) plus the green / red flash for the key just played.
    private var highlights: [Int: Color] {
        var result: [Int: Color] = [:]
        if let glow = viewModel.glowKeyId { result[glow] = Color.yellow }
        if let correct = correctFlashKey { result[correct] = Color.green }
        if let wrong = wrongFlashKey { result[wrong] = Color.red }
        return result
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

            HStack(spacing: 8) {
                Text("Round")
                    .font(.subheadline)
                Text("\(viewModel.roundsCleared + 1)")
                    .font(.custom("BalooDa-Regular", size: 36))
            }
            .foregroundColor(Color.darkGreen)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(height: 80)
    }

    /// Alpanica, the big "Listen… / Your turn!" status and the phrase's progress dots.
    private var statusPanel: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 32) {
                AlpanicaView(mood: mood, hopTrigger: viewModel.roundsCleared, height: min(240, geo.size.height * 0.9))
                    .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    Text(statusText)
                        .font(.custom("BalooDa-Regular", size: 52))
                        .foregroundColor(Color.darkGreen)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    progressDots
                }
                .frame(maxWidth: .infinity)

                Color.clear.frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var statusText: LocalizedStringKey {
        switch viewModel.phase {
        case .ready, .listening: return "👂 Listen…"
        case .yourTurn: return "🎹 Your turn!"
        case .roundCleared: return "⭐ Round cleared!"
        case .mistake: return "Oops! Listen again…"
        case .won: return "You did it!"
        case .lost: return "Out of hearts"
        }
    }

    /// One dot per note of the phrase: filled as it plays, then as the player gets each note right.
    private var progressDots: some View {
        let count = viewModel.phrase.count
        return HStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.darkGreen.opacity(0.5), lineWidth: 2))
            }
        }
        .frame(height: 30)
    }

    private func dotColor(for index: Int) -> Color {
        switch viewModel.phase {
        case .listening(let playing):
            return index <= playing ? Color.yellow : Color.white.opacity(0.7)
        case .yourTurn(let progress):
            return index < progress ? Color.green : Color.white.opacity(0.7)
        case .roundCleared, .won:
            return Color.green
        case .mistake, .lost, .ready:
            return Color.white.opacity(0.7)
        }
    }

    /// The name of the note just played, floating above its key, so each right answer teaches its label.
    private var nameOverlay: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            if let key = correctFlashKey, let frame = keyFrames[key] {
                Text(NoteCatalog.note(key).label)
                    .font(.custom("BalooDa-Regular", size: 56))
                    .foregroundColor(Color.darkGreen)
                    .padding(.horizontal, 18)
                    .background(Capsule().fill(Color.white))
                    .position(x: frame.midX - origin.x, y: frame.minY - origin.y - 36)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Reactions

    private func react(to outcome: EchoViewModel.Outcome) {
        switch outcome.kind {
        case .correct:
            flash(correct: outcome.keyId)
        case .wrong:
            flash(wrong: outcome.keyId)
            setMood(.sad, for: 0.8)
        }
    }

    private func flash(correct key: Int) {
        correctFlashKey = key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if correctFlashKey == key { correctFlashKey = nil }
        }
    }

    private func flash(wrong key: Int) {
        wrongFlashKey = key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if wrongFlashKey == key { wrongFlashKey = nil }
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

    /// Records the result once (the score is the number of rounds cleared) and shows the results screen after a beat.
    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        let won = viewModel.phase == .won
        let result = PlayResult(request: request, didWin: won, stars: viewModel.stars,
                                score: viewModel.roundsCleared, accuracy: nil, maxCombo: 0,
                                perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
        let rewards = ResultRecorder.record(result)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if isOnScreen {
                router.replaceTop(with: .result(result, rewards))
            }
        }
    }
}
