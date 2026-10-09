//
//  StageNodeView.swift
//  Melodissimo
//

import SwiftUI

// MARK: - How a stage looks

extension Stage {
    /// The badge art for this kind of stage.
    var iconName: String {
        switch kind {
        case .battle: return "icon_stage_battle"
        case .echo: return "icon_stage_echo"
        case .song: return "icon_stage_song"
        case .boss: return "icon_stage_boss"
        case .finale: return "icon_stage_finale"
        }
    }

    var fallbackEmoji: String {
        switch kind {
        case .battle: return "⚡️"
        case .echo: return "👂"
        case .song: return "🎵"
        case .boss: return "👑"
        case .finale: return "🏳️"
        }
    }

    var kindTitle: LocalizedStringKey {
        switch kind {
        case .battle: return "Battle"
        case .echo: return "Echo"
        case .song: return "Song"
        case .boss: return "Boss"
        case .finale: return "Finale"
        }
    }

    /// The song this stage plays, if it is a song, boss or finale stage.
    var song: Song? {
        switch kind {
        case .song(let id), .boss(let id), .finale(let id): return SongLibrary.song(id: id)
        case .battle, .echo: return nil
        }
    }

    var title: LocalizedStringKey {
        switch kind {
        case .battle:
            return index == 1 ? "Meet the notes" : "Note Battle"
        case .echo(let config):
            return config.glowDuringPlayback ? "Echo" : "Echo: no peeking"
        case .song, .boss, .finale:
            return LocalizedStringKey(song?.title ?? "")
        }
    }

    /// Bosses and the finale get a bigger node.
    var isLandmark: Bool {
        switch kind {
        case .boss, .finale: return true
        case .battle, .echo, .song: return false
        }
    }
}

// MARK: - Node

/// One stage on the map: its badge, the stars earned, and a lock when it isn't open yet.
struct StageNodeView: View {
    let stage: Stage
    let stars: Int
    let isUnlocked: Bool
    let isCurrent: Bool

    private var size: CGFloat { stage.isLandmark ? 96 : 76 }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                AssetImage(name: stage.iconName, fallbackEmoji: stage.fallbackEmoji)
                    .frame(width: size, height: size)
                    .saturation(isUnlocked ? 1 : 0)
                    .opacity(isUnlocked ? 1 : 0.55)

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.custom("BalooDa-Regular", size: 30))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
            }
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isCurrent ? 5 : 0)
                    .frame(width: size - 4, height: size - 4)
            )

            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < stars ? "star.fill" : "star")
                        .font(.custom("BalooDa-Regular", size: 16))
                        .foregroundColor(index < stars ? Color.yellow : Color.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.25), radius: 1)
                }
            }
            .opacity(isUnlocked ? 1 : 0.6)
        }
        .accessibilityElement(children: .combine)
    }
}
