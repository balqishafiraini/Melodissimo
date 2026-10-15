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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var engine: RhythmEngine
    /// Real-pianika mode: the microphone's notes drive the engine instead of (or as well as) touches.
    @StateObject private var mic = MicrophoneInput()
    /// The song's instrumental, following the engine's clock. Idle when the song has none or it is switched off.
    @StateObject private var backing = BackingTrackPlayer()
    /// Key frames in window coordinates, from the keyboard, so the highway lanes line up with the keys.
    @State private var keyFrames: [Int: CGRect] = [:]
    /// Practice: the key that was just pressed wrongly, flashed red for a moment (set from the scoreboard's
    /// `lastWrongPress`, which this view subscribes to without observing the rest of the scoreboard).
    @State private var wrongFlashKeyId: Int?
    /// False once the player has left, so a pending hop to the results screen can't hit the wrong screen.
    @State private var isOnScreen = true
    @State private var hasRecordedResult = false
    /// When each key was last pressed, for the highway's lane flash.
    @State private var laneFlashes = LaneFlashes()

    let song: Song
    let mode: StageMode
    let speed: Double
    let isBoss: Bool
    let isSolemn: Bool
    let campaignStageId: String?
    /// Set when this stage is the day's challenge (a song sprint), so the result pays the daily reward.
    let dailyDateKey: String?
    let showLabels: Bool
    /// True when the player chose "Real pianika" in Settings and the stage takes input (not Listen).
    let usesMicrophone: Bool
    /// True when the backing track plays: it is on in Settings, the stage is not in Real pianika mode, the stage
    /// plays the bundled chart (not the Chart Recorder's preview) and the song has a track.
    let usesBacking: Bool

    /// `chart` plays a specific chart (the Chart Recorder's preview) instead of the song's bundled one.
    init(song: Song, mode: StageMode, speed: Double = 1, isBoss: Bool = false, isSolemn: Bool = false,
         noteLimit: Int? = nil, campaignStageId: String? = nil, showKeyLabels: Bool? = nil,
         dailyDateKey: String? = nil, chart: SongChart? = nil) {
        self.song = song
        self.mode = mode
        self.speed = speed
        self.isBoss = isBoss
        self.isSolemn = isSolemn
        self.campaignStageId = campaignStageId
        self.dailyDateKey = dailyDateKey
        // Practice and Listen teach the fingering, so they show labels; Perform follows the setting.
        self.showLabels = showKeyLabels ?? (mode != .perform || ProgressStore.shared.labelsInPerform)
        let microphone = mode != .listen && ProgressStore.shared.inputMode == .pianika
        self.usesMicrophone = microphone
        let backingOn = ProgressStore.shared.backingTrackEnabled && !microphone && chart == nil
            && BackingTrackPlayer.isAvailable(for: song.id)
        self.usesBacking = backingOn
        _engine = StateObject(wrappedValue: {
            var playedChart = chart ?? SongChart.load(for: song)
            if let noteLimit { playedChart.notes = Array(playedChart.notes.prefix(noteLimit)) }
            // Read once per play: the settings screen can't be open while a stage is.
            let settings = ProgressStore.shared
            // A track with an intro needs a longer pre-roll than the 3-2-1 count-in.
            var leadIn = 0.0
            if backingOn, let offset = playedChart.offset {
                leadIn = BackingSchedule.leadIn(offset: offset, speed: speed,
                                                countIn: RhythmEngine.countInBeats * 60 / (playedChart.bpm * speed))
            }
            return RhythmEngine(chart: playedChart, mode: mode, speed: speed,
                                approachTime: settings.approachTime, audioOffsetMs: settings.audioOffsetMs,
                                windowBonus: microphone ? Judge.microphoneBonus : 0, leadIn: leadIn)
        }())
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                hud
                    .frame(height: hudHeight)

                NoteHighwayView(engine: engine, keyFrames: keyFrames,
                                showsPopups: mode == .perform, isSolemn: isSolemn,
                                laneFlashes: isSolemn ? nil : laneFlashes, reduceMotion: reduceMotion)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background((isSolemn ? Color.navy.opacity(0.55) : Color.black.opacity(0.35)).ignoresSafeArea(edges: .horizontal))

                PianoKeyboard(metrics: .stage,
                              showLabels: showLabels,
                              highlights: highlights,
                              playsSound: !usesMicrophone,
                              onNoteOn: { keyId in
                                  let now = CACurrentMediaTime()
                                  laneFlashes.press(keyId: keyId, at: now)
                                  engine.press(keyId: keyId, now: now)
                              },
                              onKeyFrames: { frames in
                                  if frames != keyFrames { keyFrames = frames }
                              },
                              pressedFromOutside: pressedFromOutside)
            }
            // The iPad keyboard runs to the bottom edge; on iPhone it stays above the home indicator.
            .ignoresSafeArea(edges: Sizing.isPhone ? [] : .bottom)

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
        .playScreen()
        .onChange(of: scenePhase) { newPhase in
            // Leaving the app (or an alert / Control Center covering it) must not let the song run on.
            if newPhase != .active {
                engine.pause(now: CACurrentMediaTime())
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AudioSessionController.didInterrupt)) { _ in
            // A call, Siri or an alarm took the audio: pause; the overlay lets the player resume.
            engine.pause(now: CACurrentMediaTime())
        }
        .onReceive(NotificationCenter.default.publisher(for: AudioSessionController.routeChanged)) { note in
            // Headphones unplugged or a Bluetooth speaker switched off: don't carry on through the phone speaker.
            if AudioSessionController.routeChangeReason(of: note) == .oldDeviceUnavailable {
                engine.pause(now: CACurrentMediaTime())
            }
        }
        .onReceive(engine.scoreboard.$lastWrongPress.dropFirst().compactMap { $0 }) { wrong in
            flashWrongKey(wrong)
        }
        .task(id: engine.phase) {
            await tickThroughCountIn()
        }
        .onChange(of: engine.phase) { newPhase in
            if newPhase == .finished { finish() }
        }
        .task {
            await startPlaying()
        }
        .onAppear {
            isOnScreen = true
            engine.attachTicker()
            // Sound effects fire the moment a hit, miss or wrong press is judged, not a render later. The closure
            // lives on the engine, so it captures two plain values and nothing else.
            let mode = mode, isSolemn = isSolemn
            engine.onJudgment = { judgment in
                guard !isSolemn else { return }
                switch judgment {
                case nil: SFX.play(.wrong)
                case .perfect? where mode == .perform: SFX.play(.perfect)
                case .miss? where mode == .perform: SFX.play(.miss)
                default: break
                }
            }
            if usesMicrophone {
                mic.onNote = { keyId, hostTime in
                    laneFlashes.press(keyId: keyId, at: hostTime)
                    engine.press(keyId: keyId, now: hostTime)
                }
                mic.start()
            }
        }
        .onDisappear {
            isOnScreen = false
            engine.onClockEvent = nil
            engine.onJudgment = nil
            backing.stop()
            engine.detachTicker()
            mic.onNote = nil
            mic.stop()
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
        if usesMicrophone, let heard = mic.currentKeyId { return [heard] }
        guard mode == .listen, let key = engine.hintKeyId else { return [] }
        return [key]
    }

    /// Loads the backing track (off the main thread), then starts the count-in, so the stage never stutters at its
    /// start. The track must be listening before the clock starts, so it hears the first `.running`. A view that
    /// is gone by then, or already past `.ready` (the task runs again on re-appearing), starts nothing.
    private func startPlaying() async {
        guard engine.phase == .ready else { return }
        if usesBacking, let offset = engine.chart.offset {
            await backing.load(songId: song.id, offset: offset, speed: speed)
            engine.onClockEvent = { [weak backing] event in backing?.handle(event) }
        }
        guard !Task.isCancelled, isOnScreen else { return }
        engine.start(now: CACurrentMediaTime())
    }

    /// A tick on each 3-2-1 of the count-in. Cancelled when the phase changes (pause, start), so
    /// a resume starts the ticking again from the current number.
    private func tickThroughCountIn() async {
        guard engine.phase == .countIn, !isSolemn else { return }
        let secondsPerBeat = engine.countInDuration / RhythmEngine.countInBeats
        var lastNumber = 0
        while !Task.isCancelled, engine.phase == .countIn {
            let songTime = engine.songTime(now: CACurrentMediaTime())
            if let count = CountIn.display(songTime: songTime, secondsPerBeat: secondsPerBeat), count.number != lastNumber {
                lastNumber = count.number
                SFX.play(.tick)
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// Practice: the key pressed wrongly flashes red for 0.3 s.
    private func flashWrongKey(_ wrong: WrongPress) {
        guard mode == .practice else { return }
        wrongFlashKeyId = wrong.keyId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if engine.scoreboard.lastWrongPress == wrong { wrongFlashKeyId = nil }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var background: some View {
        // `ignoresSafeArea` goes last: `.clipped()` clips to the layout bounds, which stay inside the safe area when
        // the view only extends itself, leaving white strips beside the Dynamic Island on iPhone.
        if isSolemn {
            // Calm: sky and grass, a faint flag, no characters.
            Color.vanila
                .overlay {
                    Image("stage_bg_ceremony")
                        .resizable()
                        .scaledToFill()
                }
                .overlay(alignment: .top) {
                    Image(systemName: "flag.fill")
                        .font(.custom("BalooDa-Regular", size: Sizing.f(120)))
                        .foregroundColor(Color.red.opacity(0.18))
                        .padding(.top, Sizing.s(90))
                }
                .clipped()
                .ignoresSafeArea()
        } else {
            // Background (not a ZStack child) so the scaledToFill image can't widen the layout.
            Color.navy
                .overlay {
                    Image("stage_bg_concert")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .ignoresSafeArea()
        }
    }

    private var hudTextColor: Color {
        isSolemn ? Color.darkGreen : .white
    }

    /// Pause, title, score and combo (or the mode's name when nothing is scored), with a thin
    /// progress bar along the bottom edge.
    private var hud: some View {
        HStack(spacing: Sizing.s(16)) {
            SoundButton {
                engine.pause(now: CACurrentMediaTime())
            } label: {
                Image(systemName: "pause.fill")
                    .frame(width: Sizing.tap(56), height: Sizing.tap(56))
                    .background(Color.yellow)
                    .foregroundColor(Color.darkGreen)
                    .cornerRadius(Sizing.s(20))
                    .font(Font.title2)
            }
            .disabled(engine.phase == .finished)
            .accessibilityLabel(Text("Pause"))

            Spacer()

            Text(song.title)
                .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
                .foregroundColor(hudTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            StageHUDScore(scoreboard: engine.scoreboard, mode: mode, isSolemn: isSolemn, isBoss: isBoss,
                          bossKind: bossKind, totalNotes: engine.totalNotes, textColor: hudTextColor)
        }
        .padding(.horizontal, Sizing.s(24))
        .overlay(alignment: .bottom) {
            StageProgressBar(scoreboard: engine.scoreboard, totalNotes: engine.totalNotes, color: hudTextColor)
                .padding(.horizontal, Sizing.s(24))
        }
    }

    /// The HUD's height. On iPhone it is slim so the highway keeps at least 180 pt: 48 pt (56 with a boss),
    /// and 44 pt (48 with a boss) on the shortest phone.
    private var hudHeight: CGFloat {
        guard Sizing.isPhone else { return isBoss ? 92 : 72 }
        if Sizing.isCompactHeight { return isBoss ? 48 : 44 }
        return isBoss ? 56 : 48
    }

    /// Which island's Fals this boss is: the chapter of the campaign stage (the first one in Free Play).
    private var bossKind: Int {
        campaignStageId.flatMap { CampaignCatalog.stage(id: $0)?.chapter } ?? 1
    }

    /// A big 3-2-1 while the song clock is still negative. Each number starts large and shrinks over its beat.
    private var countInOverlay: some View {
        TimelineView(.animation) { timeline in
            let _ = timeline.date
            let secondsPerBeat = engine.countInDuration / RhythmEngine.countInBeats
            if let count = CountIn.display(songTime: engine.songTime(now: CACurrentMediaTime()), secondsPerBeat: secondsPerBeat) {
                Text("\(count.number)")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(180)))
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
            VStack(spacing: Sizing.s(20)) {
                Text("Paused")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(48)))
                    .foregroundColor(Color.darkGreen)
                SoundButton {
                    engine.resume(now: CACurrentMediaTime())
                } label: {
                    overlayButtonLabel("Resume", filled: true)
                }
                SoundButton {
                    engine.restart(now: CACurrentMediaTime())
                } label: {
                    overlayButtonLabel("Restart", filled: false)
                }
                SoundButton {
                    router.pop()
                } label: {
                    overlayButtonLabel("Quit", filled: false)
                }
            }
            .padding(Sizing.s(40))
            .background(RoundedRectangle(cornerRadius: Sizing.s(30)).fill(Color.vanila))
        }
    }

    private func overlayButtonLabel(_ title: LocalizedStringKey, filled: Bool) -> some View {
        Text(title)
            .buttonFrame(width: 240, height: 64)
            .background(filled ? Color.darkGreen : Color.yellow)
            .foregroundColor(filled ? .white : Color.darkGreen)
            .cornerRadius(Sizing.s(20))
            .font(Font.headline)
    }

    // MARK: Finish

    /// A request to play this same song in another mode (same speed and campaign stage).
    private func request(for newMode: StageMode) -> PlayRequest {
        PlayRequest(kind: .song(songId: song.id, mode: newMode, speed: speed, isBoss: isBoss,
                                isSolemn: isSolemn, noteLimit: nil),
                    campaignStageId: campaignStageId,
                    // Switching mode returns to that mode's default labels; replaying keeps the choice.
                    showKeyLabels: newMode == mode ? showLabels : nil,
                    dailyDateKey: dailyDateKey)
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
        VStack(spacing: Sizing.s(16)) {
            switch mode {
            case .listen:
                Text("Nice listening!")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(48)))
                overlayRow {
                    SoundButton {
                        router.replaceTop(with: .play(request(for: .practice)))
                    } label: {
                        finishedButtonLabel("Try Practice →", filled: true)
                    }
                    SoundButton {
                        router.pop()
                    } label: {
                        finishedButtonLabel("< Back", filled: false)
                    }
                }
            case .practice:
                Text("Practice complete!")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(48)))
                Text("Perform is unlocked")
                    .font(.headline)
                overlayRow {
                    SoundButton {
                        router.replaceTop(with: .play(request(for: .perform)))
                    } label: {
                        finishedButtonLabel("Perform →", filled: true)
                    }
                    SoundButton {
                        router.pop()
                    } label: {
                        finishedButtonLabel("< Back", filled: false)
                    }
                }
            case .perform:
                // The results screen follows in a moment.
                Text("Finished!")
                    .font(.custom("BalooDa-Regular", size: Sizing.f(64)))
            }
        }
        .foregroundColor(Color.darkGreen)
        .padding(Sizing.s(40))
        .background(RoundedRectangle(cornerRadius: Sizing.s(30)).fill(Color.vanila))
    }

    private func overlayRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: Sizing.s(16)) {
            content()
        }
    }

    private func finishedButtonLabel(_ title: LocalizedStringKey, filled: Bool) -> some View {
        Text(title)
            .buttonFrame(width: 180, height: 64)
            .background(filled ? Color.darkGreen : Color.yellow)
            .foregroundColor(filled ? .white : Color.darkGreen)
            .cornerRadius(Sizing.s(20))
            .font(Font.headline)
    }
}

// MARK: - HUD pieces

/// The score (with the combo) or the mode's name, and the boss badge. These are the parts of the HUD that change
/// with every hit, so they observe the scoreboard themselves and `SongStageView` doesn't re-render for a hit.
private struct StageHUDScore: View {
    @ObservedObject var scoreboard: StageScoreboard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let mode: StageMode
    let isSolemn: Bool
    let isBoss: Bool
    let bossKind: Int
    let totalNotes: Int
    let textColor: Color
    /// The combo text's scale: it pops on every tenth hit.
    @State private var comboScale: CGFloat = 1

    var body: some View {
        HStack(spacing: Sizing.s(16)) {
            scoreArea
                .foregroundColor(textColor)

            if isBoss {
                BossBadgeView(kind: bossKind,
                              health: mode == .perform
                                  ? BossHealth.fraction(counts: scoreboard.counts, totalNotes: totalNotes) : nil,
                              hitTrigger: scoreboard.counts.perfect + scoreboard.counts.great + scoreboard.counts.good)
            }
        }
        .onChange(of: scoreboard.combo) { combo in
            pulseComboIfMilestone(combo)
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
                    Text("\(scoreboard.score)")
                        .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
                        .contentTransition(.numericText())
                        .animation(.default, value: scoreboard.score)
                }
                // No combo flames on solemn songs.
                if scoreboard.combo >= 2, !isSolemn {
                    HStack(spacing: 8) {
                        Text("Combo")
                            .font(.subheadline)
                        Text("\(scoreboard.combo)")
                            .font(.custom("BalooDa-Regular", size: Sizing.f(22)))
                            .scaleEffect(comboScale, anchor: .leading)
                    }
                }
            }
        case .practice:
            Text("Practice")
                .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
        case .listen:
            Text("Listen")
                .font(.custom("BalooDa-Regular", size: Sizing.f(28)))
        }
    }

    /// Every tenth hit the combo number swells and settles, which is also when the multiplier steps up.
    /// Solemn songs and Reduce Motion skip it.
    private func pulseComboIfMilestone(_ combo: Int) {
        guard ComboPulse.isMilestone(combo), !isSolemn, !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.1)) { comboScale = 1.6 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { comboScale = 1 }
        }
    }
}

/// Notes judged so far over all notes. It moves only when a note is judged (the scoreboard says so), so it needs no
/// timeline redrawing it every frame.
private struct StageProgressBar: View {
    @ObservedObject var scoreboard: StageScoreboard
    let totalNotes: Int
    let color: Color

    var body: some View {
        let fraction = totalNotes == 0 ? 0 : Double(scoreboard.judgedCount) / Double(totalNotes)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2))
                Capsule().fill(Color.yellow)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
    }
}
