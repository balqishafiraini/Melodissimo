//
//  ResultRecorder.swift
//  Melodissimo
//

import Foundation

/// The only place that writes progress after a play: bests, stars, flags, stats, the daily
/// streak and achievements. It is called once per play, before the results screen is shown.
struct ResultRecorder {
    let progress: ProgressStore
    /// Checks the achievements and returns the titles that were just unlocked.
    let evaluateAchievements: () -> [String]

    static let shared = ResultRecorder()

    init(progress: ProgressStore = .shared,
         evaluateAchievements: @escaping () -> [String] = { AchievementStore.shared.evaluate().map(\.title) }) {
        self.progress = progress
        self.evaluateAchievements = evaluateAchievements
    }

    @discardableResult
    static func record(_ result: PlayResult) -> RewardSummary {
        shared.record(result)
    }

    /// Applies a finished play to the stored progress and says what it earned.
    @discardableResult
    func record(_ result: PlayResult) -> RewardSummary {
        var summary = RewardSummary()

        switch result.request.kind {
        case .song(let songId, let mode, _, _, _, _):
            // Listening teaches but earns nothing, and doesn't count as playing today.
            guard mode != .listen else { return summary }
            switch mode {
            case .practice:
                progress.setSongPracticed(songId)
            case .perform:
                summary = recordPerform(result, songId: songId)
            case .listen:
                break
            }
        case .classic(let levelNo):
            recordClassic(result, levelNo: levelNo)
        case .rush:
            summary.isNewBest = progress.recordRushScore(result.score)
        case .battle, .echo, .daily:
            break   // each mode records its own results in its own task
        }

        progress.recordCombo(result.maxCombo)
        progress.registerPlayToday()
        summary.newAchievements = evaluateAchievements()
        return summary
    }

    /// The classic 100 levels keep their legacy storage: the first-try percentage (carried in
    /// `accuracy`) is the level's best score, which the grid turns into stars at 60 / 80 / 100 %,
    /// and winning unlocks the next level. Winning with a mistake or two now counts, where the old
    /// quiz only unlocked on a flawless run.
    private func recordClassic(_ result: PlayResult, levelNo: Int) {
        progress.recordScore(category: "notation", level: levelNo, score: Int(result.accuracy ?? 0))
        if result.didWin {
            progress.unlock(upToLevel: levelNo)
        }
    }

    private func recordPerform(_ result: PlayResult, songId: String) -> RewardSummary {
        var summary = RewardSummary()

        summary.isNewBest = progress.recordSongScore(songId, score: result.score)
        if let accuracy = result.accuracy {
            progress.recordSongAccuracy(songId, accuracy: accuracy)
        }
        summary.newStars = progress.recordSongStars(songId, stars: result.stars)

        // No misses and no wrong presses: count each song's first full combo.
        if result.miss == 0, result.wrong == 0, progress.setSongFullCombo(songId) {
            progress.incrementFullCombos()
        }
        progress.incrementSongsPerformed()

        // The trophy shelf predates the game modes: a 3-star Perform earns the song's trophy.
        if result.stars == 3, let song = SongLibrary.song(id: songId) {
            progress.defaults.set(true, forKey: song.title)
        }
        return summary
    }
}
