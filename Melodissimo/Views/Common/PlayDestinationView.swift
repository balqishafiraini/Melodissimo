//
//  PlayDestinationView.swift
//  Melodissimo
//

import SwiftUI

/// Maps a `PlayRequest` to the screen that plays it. Each play mode adds its case here.
struct PlayDestinationView: View {
    let request: PlayRequest

    var body: some View {
        switch request.kind {
        case .song(let songId, let mode, let speed, let isBoss, let isSolemn, let noteLimit):
            if let song = SongLibrary.song(id: songId) {
                SongStageView(song: song, mode: mode, speed: speed, isBoss: isBoss, isSolemn: isSolemn,
                              noteLimit: noteLimit, campaignStageId: request.campaignStageId,
                              showKeyLabels: request.showKeyLabels)
            } else {
                UnavailableModeView()
            }
        case .battle, .classic, .echo, .rush, .daily:
            UnavailableModeView()
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
