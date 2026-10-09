//
//  SongStageView.swift
//  Melodissimo
//

import SwiftUI

/// Plays one song as a falling-notes rhythm stage: HUD on top, the note highway in the
/// middle, the pianika keyboard at the bottom.
///
/// - **Listen**: autoplay; keys light up and sound as the notes arrive.
/// - **Practice**: the song waits at the hit line for the right key; a wrong key flashes red and
///   the right key glows after a struggle.
/// - **Perform**: real time, judged, scored.
///
/// Solemn songs (the national anthem and *Mengheningkan Cipta*) get a calm backdrop, no combo
/// text and only a quiet check mark instead of judgment popups.
struct SongStageView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var engine: RhythmEngine
    /// Key frames in window coordinates, from the keyboard, so the highway lanes line up with the keys.
    @State private var keyFrames: [Int: CGRect] = [:]
    /// Practice: the key that was just pressed wrongly, flashed red for a moment.
    @State private var wrongFlashKeyId: Int?
    /// False once the player has left, so a pending hop to the results screen can't hit the wrong screen.
    @State private var isOnScreen = true
    @State private var hasRecordedResult = false

    let song: Song
    let mode: StageMode
    let speed: Double
    let isBoss: Bool
    let isSolemn: Bool
    let campaignStageId: String?
    let showLabels: Bool

    /// Seconds a note takes to fall to the hit line (a setting later on).
    static let approachTime = 2.0

    /// `chart` plays a specific chart (the Chart Recorder's preview) instead of the song's bundled one.
    init(song: Song, mode: StageMode, speed: Double = 1, isBoss: Bool = false, isSolemn: Bool = false,
         noteLimit: Int? = nil, campaignStageId: String? = nil, showKeyLabels: Bool? = nil, chart: SongChart? = nil) {
        self.song = song
        self.mode = mode
        self.speed = speed
        self.isBoss = isBoss
        self.isSolemn = isSolemn
        self.campaignStageId = campaignStageId
        // Practice and Listen teach the fingering, so they show labels; Perform follows the setting.
        self.showLabels = showKeyLabels ?? (mode != .perform || ProgressStore.shared.labelsInPerform)
        _engine = StateObject(wrappedValue: {
            var playedChart = chart ?? SongChart.load(for: song)
            if let noteLimit { playedChart.notes = Array(playedChart.notes.prefix(noteLimit)) }
            return RhythmEngine(chart: playedChart, mode: mode, speed: speed, approachTime: SongStageView.approachTime)
        }())
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                hud
                    .frame(height: 72)

                NoteHighwayView(engine: engine, keyFrames: keyFrames,
                                showsPopups: mode == .perform, isSolemn: isSolemn)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(isSolemn ? Color.navy.opacity(0.55) : Color.black.opacity(0.35))

                PianoKeyboard(metrics: .stage,
                              showLabels: showLabels,
                              highlights: highlights,
                              onNoteOn: { engine.press(keyId: $0, now: CACurrentMediaTime()) },
                              onKeyFrames: { frames in
                                  if frames != keyFrames { keyFrames = frames }
                              },
                              pressedFromOutside: pressedFromOutside)
            }
            .ignoresSafeArea(edges: .bottom)

            if engine.phase == .countIn {
                countInOverlay
            }

            if engine.phase == .paused {
                pauseOverlay
            }

            if engine.phase == .finished {
                finishedOverlay
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // Leaving the app (or an alert / Control Center covering it) must not let the song run on.
            if newPhase != .active {
                engine.pause(now: CACurrentMediaTime())
            }
        }
        .onChange(of: engine.wrongPresses) { _ in
            flashWrongKeyIfPracticing()
        }
        .onChange(of: engine.phase) { newPhase in
            if newPhase == .finished { finish() }
        }
        .onAppear {
            isOnScreen = true
            engine.attachTicker()
            engine.start(now: CACurrentMediaTime())
        }
        .onDisappear {
            isOnScreen = false
            engine.detachTicker()
        }
    }

    // MARK: Keyboard state

    /// Practice: the key to play glows yellow after a struggle; a wrong key flashes red.
    private var highlights: [Int: Color] {
        var result: [Int: Color] = [:]
        if mode == .practice, let hint = engine.hintKeyId {
            result[hint] = Color.yellow
        }
        if let wrong = wrongFlashKeyId {
            result[wrong] = Color.red
        }
        return result
    }

    /// Listen: the key that is sounding is drawn pressed, as if an invisible player held it.
    private var pressedFromOutside: Set<Int> {
        guard mode == .listen, let key = engine.hintKeyId else { return [] }
        return [key]
    }

    private func flashWrongKeyIfPracticing() {
        guard mode == .practice, let event = engine.recentEvents.last, event.judgment == nil else { return }
        let key = event.keyId
        wrongFlashKeyId = key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if wrongFlashKeyId == key { wrongFlashKeyId = nil }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var background: some View {
        if isSolemn {
            // Calm: sky and grass, a faint flag, no characters.
            Color.vanila
                .ignoresSafeArea()
                .overlay {
                    Image("stage_bg_ceremony")
                        .resizable()
                        .scaledToFill()
                }
                .overlay(alignment: .top) {
                    Image(systemName: "flag.fill")
                        .font(.custom("BalooDa-Regular", size: 120))
                        .foregroundColor(Color.red.opacity(0.18))
                        .padding(.top, 90)
                }
                .clipped()
        } else {
            // Background (not a ZStack child) so the scaledToFill image can't widen the layout.
            Color.navy
                .ignoresSafeArea()
                .overlay {
                    Image("stage_bg_concert")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        }
    }

    private var hudTextColor: Color {
        isSolemn ? Color.darkGreen : .white
    }

    /// Pause, title, score and combo (or the mode's name when nothing is scored), with a thin
    /// progress bar along the bottom edge.
    private var hud: some View {
        HStack(spacing: 16) {
            Button {
                engine.pause(now: CACurrentMediaTime())
            } label: {
                Image(systemName: "pause.fill")
                    .frame(width: 56, height: 56)
                    .background(Color.yellow)
                    .foregroundColor(Color.darkGreen)
                    .cornerRadius(20)
                    .font(Font.title2)
            }
            .disabled(engine.phase == .finished)
            .accessibilityLabel(Text("Pause"))

            Spacer()

            Text(song.title)
                .font(.custom("BalooDa-Regular", size: 28))
                .foregroundColor(hudTextColor)
                .lineLimit(1)

            Spacer()

            scoreArea
                .foregroundColor(hudTextColor)
        }
        .padding(.horizontal, 24)
        .overlay(alignment: .bottom) {
            progressBar
        }
    }

    @ViewBuilder
    private var scoreArea: some View {
        switch mode {
        case .perform:
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 8) {
                    Text("Score")
                        .font(.subheadline)
                    Text("\(engine.score)")
                        .font(.custom("BalooDa-Regular", size: 28))
                        .contentTransition(.numericText())
                        .animation(.default, value: engine.score)
                }
                // No combo flames on solemn songs.
                if engine.combo >= 2, !isSolemn {
                    HStack(spacing: 8) {
                        Text("Combo")
                            .font(.subheadline)
                        Text("\(engine.combo)")
                            .font(.custom("BalooDa-Regular", size: 22))
                    }
                }
            }
        case .practice:
            Text("Practice")
                .font(.custom("BalooDa-Regular", size: 28))
        case .listen:
            Text("Listen")
                .font(.custom("BalooDa-Regular", size: 28))
        }
    }

    /// Notes judged so far over all notes. Redrawn every frame so Listen and Practice, which don't
    /// publish per note, still move it.
    private var progressBar: some View {
        TimelineView(.animation) { timeline in
            let _ = timeline.date
            let fraction = engine.totalNotes == 0 ? 0 : Double(engine.judgedCount) / Double(engine.totalNotes)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(hudTextColor.opacity(0.2))
                    Capsule().fill(Color.yellow)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 24)
    }

    /// A big 3-2-1 while the song clock is still negative. Each number starts large and shrinks over its beat.
    private var countInOverlay: some View {
        TimelineView(.animation) { timeline in
            let _ = timeline.date
            let secondsPerBeat = engine.countInDuration / RhythmEngine.countInBeats
            if let count = CountIn.display(songTime: engine.songTime(now: CACurrentMediaTime()), secondsPerBeat: secondsPerBeat) {
                Text("\(count.number)")
                    .font(.custom("BalooDa-Regular", size: 180))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
                    .scaleEffect(1.3 - 0.3 * count.progress)
                    .opacity(1 - 0.4 * count.progress)
            }
        }
        .allowsHitTesting(false)
    }

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Paused")
                    .font(.custom("BalooDa-Regular", size: 48))
                    .foregroundColor(Color.darkGreen)
                Button {
                    engine.resume(now: CACurrentMediaTime())
                } label: {
                    overlayButtonLabel("Resume", filled: true)
                }
                Button {
                    engine.restart(now: CACurrentMediaTime())
                } label: {
                    overlayButtonLabel("Restart", filled: false)
                }
                Button {
                    router.pop()
                } label: {
                    overlayButtonLabel("Quit", filled: false)
                }
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 30).fill(Color.vanila))
        }
    }

    private func overlayButtonLabel(_ title: LocalizedStringKey, filled: Bool) -> some View {
        Text(title)
            .frame(width: 240, height: 64)
            .background(filled ? Color.darkGreen : Color.yellow)
            .foregroundColor(filled ? .white : Color.darkGreen)
            .cornerRadius(20)
            .font(Font.headline)
    }

    // MARK: Finish

    /// A request to play this same song in another mode (same speed and campaign stage).
    private func request(for newMode: StageMode) -> PlayRequest {
        PlayRequest(kind: .song(songId: song.id, mode: newMode, speed: speed, isBoss: isBoss,
                                isSolemn: isSolemn, noteLimit: nil),
                    campaignStageId: campaignStageId,
                    // Switching mode returns to that mode's default labels; replaying keeps the choice.
                    showKeyLabels: newMode == mode ? showLabels : nil)
    }

    /// Records what the play earned, once. Perform then shows the results screen after a short
    /// pause so the last judgment popup can be seen; Practice stays on its own finish overlay.
    private func finish() {
        guard !hasRecordedResult else { return }
        hasRecordedResult = true
        switch mode {
        case .listen:
            break
        case .practice:
            let result = PlayResult(request: request(for: .practice), didWin: true, stars: 0, score: 0, accuracy: nil,
                                    maxCombo: 0, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
            ResultRecorder.record(result)
        case .perform:
            let stars = engine.stars()
            let result = PlayResult(request: request(for: .perform), didWin: stars > 0, stars: stars,
                                    score: engine.score, accuracy: engine.accuracy, maxCombo: engine.maxCombo,
                                    perfect: engine.counts.perfect, great: engine.counts.great, good: engine.counts.good,
                                    miss: engine.counts.miss, wrong: engine.wrongPresses)
            let rewards = ResultRecorder.record(result)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if isOnScreen {
                    router.replaceTop(with: .result(result, rewards))
                }
            }
        }
    }

    /// Per-mode end screen. Perform only shows a short banner before the results screen.
    private var finishedOverlay: some View {
        VStack(spacing: 16) {
            switch mode {
            case .listen:
                Text("Nice listening!")
                    .font(.custom("BalooDa-Regular", size: 48))
                overlayRow {
                    Button {
                        router.replaceTop(with: .play(request(for: .practice)))
                    } label: {
                        finishedButtonLabel("Try Practice →", filled: true)
                    }
                    Button {
                        router.pop()
                    } label: {
                        finishedButtonLabel("< Back", filled: false)
                    }
                }
            case .practice:
                Text("Practice complete!")
                    .font(.custom("BalooDa-Regular", size: 48))
                Text("Perform is unlocked")
                    .font(.headline)
                overlayRow {
                    Button {
                        router.replaceTop(with: .play(request(for: .perform)))
                    } label: {
                        finishedButtonLabel("Perform →", filled: true)
                    }
                    Button {
                        router.pop()
                    } label: {
                        finishedButtonLabel("< Back", filled: false)
                    }
                }
            case .perform:
                // The results screen follows in a moment.
                Text("Finished!")
                    .font(.custom("BalooDa-Regular", size: 64))
            }
        }
        .foregroundColor(Color.darkGreen)
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 30).fill(Color.vanila))
    }

    private func overlayRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 16) {
            content()
        }
    }

    private func finishedButtonLabel(_ title: LocalizedStringKey, filled: Bool) -> some View {
        Text(title)
            .frame(width: 180, height: 64)
            .background(filled ? Color.darkGreen : Color.yellow)
            .foregroundColor(filled ? .white : Color.darkGreen)
            .cornerRadius(20)
            .font(Font.headline)
    }
}
