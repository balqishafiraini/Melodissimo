//
//  PlayDestinationView.swift
//  Melodissimo
//

import SwiftUI

/// Maps a `PlayRequest` to the screen that plays it. Each play mode adds its case here.
struct PlayDestinationView: View {
    let request: PlayRequest
    /// Endless modes (Melody Rush, endless Echo) are different every time. The seed is chosen once per
    /// screen so a re-render can't change the notes.
    @State private var freshSeed = UInt64.random(in: 1...UInt64.max)

    /// Stages keep their own fixed seed; an endless Echo run gets a fresh one each time.
    private func echoConfig(_ config: EchoConfig) -> EchoConfig {
        var fresh = config
        if fresh.roundsToClear == nil { fresh.seed = freshSeed }
        return fresh
    }

    var body: some View {
        switch request.kind {
        case .song(let songId, let mode, let speed, let isBoss, let isSolemn, let noteLimit):
            if let song = SongLibrary.song(id: songId) {
                SongStageView(song: song, mode: mode, speed: speed, isBoss: isBoss, isSolemn: isSolemn,
                              noteLimit: noteLimit, campaignStageId: request.campaignStageId,
                              showKeyLabels: request.showKeyLabels, dailyDateKey: request.dailyDateKey)
            } else {
                UnavailableModeView()
            }
        case .battle(let config):
            BattleView(request: request, config: config)
        case .classic(let levelNo):
            let levels = LevelFeederModel.shared.notationQuizLevels
            if levels.indices.contains(levelNo - 1) {
                BattleView(request: request, config: .classic(levelNo: levelNo, answers: levels[levelNo - 1].answer))
            } else {
                UnavailableModeView()
            }
        case .rush:
            BattleView(request: request, config: .rush(seed: freshSeed))
        case .echo(let config):
            EchoView(request: request, config: echoConfig(config))
        case .daily(let dateKey):
            // Play the day's mode; the date key rides along so the result pays the daily reward.
            if let challenge = DailyChallenge.make(dateKey: dateKey, chapter: ProgressStore.shared.currentStage.chapter),
               let kind = challenge.playKind {
                PlayDestinationView(request: PlayRequest(kind: kind, dailyDateKey: dateKey))
            } else {
                UnavailableModeView()
            }
        }
    }
}

/// Shown for a play mode that isn't built yet.
struct UnavailableModeView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Color.softBlue.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Coming soon")
                    .font(.custom("BalooDa-Regular", size: 48))
                    .foregroundColor(Color.darkGreen)
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
    }
}
