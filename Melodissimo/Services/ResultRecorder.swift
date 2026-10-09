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
        // Stars above the previous best (a song's own best, or the campaign stage's) and the coins this play pays.
        var starGain = 0
        var coins = 0
        var isSong = false
        var isSongPerform = false
        var isBossPerform = false

        switch result.request.kind {
        case .song(let songId, let mode, _, _, _, _):
            // Listening teaches but earns nothing, and doesn't count as playing today.
            guard mode != .listen else { return summary }
            isSong = true
            switch mode {
            case .practice:
                if !progress.isSongPracticed(songId) { coins += CoinRewards.firstPractice }
                progress.setSongPracticed(songId)
            case .perform:
                summary = recordPerform(result, songId: songId)
                starGain = summary.newStars
                isSongPerform = true
                if case .song(_, _, _, true, _, _) = result.request.kind { isBossPerform = true }
            case .listen:
                break
            }
        case .classic(let levelNo):
            recordClassic(result, levelNo: levelNo)
        case .rush:
            summary.isNewBest = progress.recordRushScore(result.score)
            coins += CoinRewards.rush(correctAnswers: result.correctCount)
        case .echo(let config):
            // `score` is the number of rounds cleared.
            progress.recordEchoBestRounds(result.score)
            if config.roundsToClear == nil {
                summary.isNewBest = progress.recordEchoHighScore(result.score)
                coins += CoinRewards.echoEndless(rounds: result.score)
            }
        case .battle, .daily:
            break   // each mode records its own results in its own task
        }

        // A campaign stage keeps the best stars of any play that was launched from the map.
        var isFirstStageClear = false
        if let stageId = result.request.campaignStageId {
            let before = progress.stageStars(stageId)
            let gained = progress.recordStageStars(stageId, stars: result.stars)
            // Songs already report their own best-star gain.
            if !isSong { summary.newStars = gained }
            starGain = max(starGain, gained)
            isFirstStageClear = before == 0 && result.stars >= 1
            // Beating a boss for the first time (a star on a stage that had none) counts towards the Fals hunter.
            if isBossPerform, isFirstStageClear {
                progress.incrementBossesDefeated()
            }
            // The first star on the national anthem finishes the tour.
            if isFirstStageClear, StoryCatalog.finaleStage()?.id == stageId {
                progress.recordTourCompleted()
            }
        }

        // Winning a campaign stage or performing a song pays by the stars it adds. Practice, Rush and
        // endless Echo were paid above, and the classic levels pay nothing.
        if result.didWin, result.stars >= 1, isSongPerform || result.request.campaignStageId != nil {
            coins += CoinRewards.clear(newStars: starGain,
                                       isFirstStageClear: isFirstStageClear,
                                       isFirstBossClear: isFirstStageClear && isBossPerform)
        }

        progress.earn(coins)
        summary.coins = coins

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
