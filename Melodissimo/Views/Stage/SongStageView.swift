//
//  SongStageView.swift
//  Melodissimo
//

import SwiftUI

/// Plays one song as a falling-notes rhythm stage: HUD on top, the note highway in the
/// middle, the pianika keyboard at the bottom.
struct SongStageView: View {
    @EnvironmentObject private var router: AppRouter
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

                NoteHighwayView(engine: engine, keyFrames: keyFrames)
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

            if engine.phase == .finished {
                finishedOverlay
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

    /// Placeholder HUD: back, title, score and combo. The real one arrives with the pause and count-in work.
    private var hud: some View {
        HStack(spacing: 16) {
            Button {
                router.pop()
            } label: {
                Text("< Back")
                    .frame(width: 110, height: 56)
                    .background(Color.yellow)
                    .foregroundColor(Color.darkGreen)
                    .cornerRadius(20)
                    .font(Font.headline)
            }

            Spacer()

            Text(song.title)
                .font(.custom("BalooDa-Regular", size: 28))
                .foregroundColor(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 8) {
                    Text("Score")
                        .font(.subheadline)
                    Text("\(engine.score)")
                        .font(.custom("BalooDa-Regular", size: 28))
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
