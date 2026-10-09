//
//  SongStageView.swift
//  Melodissimo
//

import SwiftUI

/// Plays one song as a falling-notes rhythm stage: HUD on top, the note highway in the
/// middle, the pianika keyboard at the bottom.
struct SongStageView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var engine: RhythmEngine
    /// Key frames in window coordinates, from the keyboard, so the highway lanes line up with the keys.
    @State private var keyFrames: [Int: CGRect] = [:]

    let song: Song
    let mode: StageMode
    let speed: Double
    let isBoss: Bool
    let isSolemn: Bool
    let campaignStageId: String?

    /// Seconds a note takes to fall to the hit line (a setting later on).
    static let approachTime = 2.0

    init(song: Song, mode: StageMode, speed: Double = 1, isBoss: Bool = false, isSolemn: Bool = false,
         noteLimit: Int? = nil, campaignStageId: String? = nil) {
        self.song = song
        self.mode = mode
        self.speed = speed
        self.isBoss = isBoss
        self.isSolemn = isSolemn
        self.campaignStageId = campaignStageId
        _engine = StateObject(wrappedValue: {
            var chart = SongChart.load(for: song)
            if let noteLimit { chart.notes = Array(chart.notes.prefix(noteLimit)) }
            return RhythmEngine(chart: chart, mode: mode, speed: speed, approachTime: SongStageView.approachTime)
        }())
    }

    var body: some View {
        ZStack {
            // Background (not a ZStack child) so the scaledToFill image can't widen the layout.
            Color.navy
                .ignoresSafeArea()
                .overlay {
                    Image("stage_bg_concert")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()

            VStack(spacing: 0) {
                hud
                    .frame(height: 72)

                NoteHighwayView(engine: engine, keyFrames: keyFrames, showsPopups: mode == .perform)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.35))

                PianoKeyboard(metrics: .stage,
                              showLabels: false,
                              onNoteOn: { engine.press(keyId: $0, now: CACurrentMediaTime()) },
                              onKeyFrames: { frames in
                                  if frames != keyFrames { keyFrames = frames }
                              })
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
        .onAppear {
            engine.attachTicker()
            engine.start(now: CACurrentMediaTime())
        }
        .onDisappear {
            engine.detachTicker()
        }
    }

    // MARK: Pieces

    /// Pause, title, score and combo, with a thin progress bar along the bottom edge.
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
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 8) {
                    Text("Score")
                        .font(.subheadline)
                    Text("\(engine.score)")
                        .font(.custom("BalooDa-Regular", size: 28))
                        .contentTransition(.numericText())
                        .animation(.default, value: engine.score)
                }
                if engine.combo >= 2 {
                    HStack(spacing: 8) {
                        Text("Combo")
                            .font(.subheadline)
                        Text("\(engine.combo)")
                            .font(.custom("BalooDa-Regular", size: 22))
                    }
                }
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .overlay(alignment: .bottom) {
            progressBar
        }
    }

    /// Notes judged so far over all notes. Redrawn every frame so Listen and Practice, which don't
    /// publish per note, move it too.
    private var progressBar: some View {
        TimelineView(.animation) { timeline in
            let _ = timeline.date
            let fraction = engine.totalNotes == 0 ? 0 : Double(engine.judgedCount) / Double(engine.totalNotes)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
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
                    pauseButtonLabel("Resume", filled: true)
                }
                Button {
                    engine.restart(now: CACurrentMediaTime())
                } label: {
                    pauseButtonLabel("Restart", filled: false)
                }
                Button {
                    router.pop()
                } label: {
                    pauseButtonLabel("Quit", filled: false)
                }
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 30).fill(Color.vanila))
        }
    }

    private func pauseButtonLabel(_ title: LocalizedStringKey, filled: Bool) -> some View {
        Text(title)
            .frame(width: 240, height: 64)
            .background(filled ? Color.darkGreen : Color.yellow)
            .foregroundColor(filled ? .white : Color.darkGreen)
            .cornerRadius(20)
            .font(Font.headline)
    }

    /// Placeholder end screen until the real results screen exists.
    private var finishedOverlay: some View {
        VStack(spacing: 16) {
            Text("Finished!")
                .font(.custom("BalooDa-Regular", size: 48))
            Text("\(engine.score)")
                .font(.custom("BalooDa-Regular", size: 64))
            HStack(spacing: 16) {
                Button {
                    engine.restart(now: CACurrentMediaTime())
                } label: {
                    Text("Retry")
                        .frame(width: 140, height: 64)
                        .background(Color.yellow)
                        .foregroundColor(Color.darkGreen)
                        .cornerRadius(20)
                        .font(Font.headline)
                }
                Button {
                    router.pop()
                } label: {
                    Text("< Back")
                        .frame(width: 140, height: 64)
                        .background(Color.darkGreen)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .font(Font.headline)
                }
            }
        }
        .foregroundColor(Color.darkGreen)
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 30).fill(Color.vanila))
    }
}
