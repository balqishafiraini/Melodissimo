import XCTest
@testable import Melodissimo

final class GameCenterTests: XCTestCase {

    private func result(_ kind: PlayRequest.Kind, score: Int, stage: String? = nil) -> PlayResult {
        PlayResult(request: PlayRequest(kind: kind, campaignStageId: stage), didWin: true, stars: 1, score: score,
                   accuracy: nil, maxCombo: 0, perfect: 0, great: 0, good: 0, miss: 0, wrong: 0)
    }

    func testRushPostsItsScore() {
        XCTAssertEqual(LeaderboardSubmissions.scores(for: result(.rush, score: 240), tourStars: 0),
                       [LeaderboardScore(leaderboardID: LeaderboardID.rush, value: 240)])
    }

    func testEchoPostsRoundsCleared() {
        let echo = EchoConfig(pool: [5, 6], roundsToClear: nil, seed: 1)
        XCTAssertEqual(LeaderboardSubmissions.scores(for: result(.echo(echo), score: 7), tourStars: 0),
                       [LeaderboardScore(leaderboardID: LeaderboardID.echo, value: 7)])
    }

    func testACampaignStageAlsoPostsTotalStars() {
        let echo = EchoConfig(pool: [5, 6], roundsToClear: 3, seed: 1)
        let scores = LeaderboardSubmissions.scores(for: result(.echo(echo), score: 3, stage: "c1-03"), tourStars: 11)
        XCTAssertEqual(Set(scores), [LeaderboardScore(leaderboardID: LeaderboardID.echo, value: 3),
                                     LeaderboardScore(leaderboardID: LeaderboardID.stars, value: 11)])
    }

    func testZerosAndFreePlayPostNothing() {
        XCTAssertTrue(LeaderboardSubmissions.scores(for: result(.rush, score: 0), tourStars: 0).isEmpty)
        XCTAssertTrue(LeaderboardSubmissions.scores(for: result(.classic(levelNo: 4), score: 90), tourStars: 30).isEmpty,
                      "total stars are only posted by a campaign play")
        XCTAssertTrue(LeaderboardSubmissions.scores(for: result(.rush, score: 5, stage: "c1-01"), tourStars: 0)
            .allSatisfy { $0.leaderboardID == LeaderboardID.rush })
    }

    func testTheRecorderHandsTheScoresToTheSubmitter() {
        let suite = "GameCenterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var posted: [LeaderboardScore] = []
        let recorder = ResultRecorder(progress: ProgressStore(defaults: defaults), evaluateAchievements: { [] },
                                      submitScores: { posted = $0 })
        recorder.record(result(.rush, score: 330))
        XCTAssertEqual(posted, [LeaderboardScore(leaderboardID: LeaderboardID.rush, value: 330)])
    }
}
