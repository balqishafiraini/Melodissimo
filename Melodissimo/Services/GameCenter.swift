//
//  GameCenter.swift
//  Melodissimo
//

import GameKit

/// One score to post to one leaderboard.
struct LeaderboardScore: Hashable {
    let leaderboardID: String
    let value: Int
}

/// The leaderboard ids. Create three **Classic** leaderboards with exactly these ids in App Store
/// Connect (score format: integer, higher is better).
enum LeaderboardID {
    static let rush = "melodissimo.rush"
    static let echo = "melodissimo.echo"
    static let stars = "melodissimo.stars"
}

/// Decides what a finished play posts (pure, so it is unit-tested without GameKit).
enum LeaderboardSubmissions {
    /// Rush posts its score, Echo posts the rounds cleared, and any play that can add stars
    /// posts the tour's total stars. Only the best counts on Game Center's side, so posting a
    /// lower score is harmless; zeros are skipped.
    static func scores(for result: PlayResult, tourStars: Int) -> [LeaderboardScore] {
        var scores: [LeaderboardScore] = []
        switch result.request.kind {
        case .rush:
            if result.score > 0 { scores.append(LeaderboardScore(leaderboardID: LeaderboardID.rush, value: result.score)) }
        case .echo:
            if result.score > 0 { scores.append(LeaderboardScore(leaderboardID: LeaderboardID.echo, value: result.score)) }
        default:
            break
        }
        if result.request.campaignStageId != nil, tourStars > 0 {
            scores.append(LeaderboardScore(leaderboardID: LeaderboardID.stars, value: tourStars))
        }
        return scores
    }
}

/// Game Center, used quietly: it signs the player in without ever showing Apple's sign-in sheet
/// (a child who isn't signed in just doesn't post), and posts scores only when signed in.
final class GameCenter {
    static let shared = GameCenter()

    private static var didAuthenticate = false

    /// Signs in once per launch, and only when online services are switched on (`OnlineServices`): without
    /// the Game Center entitlement the attempt fails after ~20 s of system churn. Called from Home's first
    /// appearance, so launch itself isn't competing with GameKit.
    func authenticate() {
        guard OnlineServices.isEnabled, !Self.didAuthenticate else { return }
        Self.didAuthenticate = true
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            // Silent on purpose: any sign-in screen the system offers is ignored.
        }
    }

    func submit(_ scores: [LeaderboardScore]) {
        guard !scores.isEmpty, GKLocalPlayer.local.isAuthenticated else { return }
        for score in scores {
            GKLeaderboard.submitScore(score.value, context: 0, player: GKLocalPlayer.local,
                                      leaderboardIDs: [score.leaderboardID]) { _ in }
        }
    }
}
