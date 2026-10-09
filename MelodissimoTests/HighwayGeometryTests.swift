import XCTest
@testable import Melodissimo

final class HighwayGeometryTests: XCTestCase {

    func testNoteBottomIsAtTheHitLineWhenItsTimeArrives() {
        XCTAssertEqual(HighwayGeometry.bottomY(noteTime: 5, songTime: 5, approachTime: 2, hitY: 400), 400)
    }

    func testNoteBottomIsAtTheTopOneApproachTimeEarlier() {
        XCTAssertEqual(HighwayGeometry.bottomY(noteTime: 7, songTime: 5, approachTime: 2, hitY: 400), 0)
    }

    func testNoteFallsLinearlyAndKeepsGoingPastTheLine() {
        XCTAssertEqual(HighwayGeometry.bottomY(noteTime: 6, songTime: 5, approachTime: 2, hitY: 400), 200)
        XCTAssertEqual(HighwayGeometry.bottomY(noteTime: 4.5, songTime: 5, approachTime: 2, hitY: 400), 500, "0.5 s late: 100 pt below the line")
    }

    func testLengthScalesWithDurationAndHasAMinimum() {
        XCTAssertEqual(HighwayGeometry.length(duration: 1, approachTime: 2, hitY: 400), 180)       // 0.5 × 400 × 0.9
        XCTAssertEqual(HighwayGeometry.length(duration: 0.1, approachTime: 2, hitY: 400), 24)      // would be 18
        XCTAssertEqual(HighwayGeometry.length(duration: 0.01, approachTime: 2, hitY: 100), 24)
    }

    func testVisibilityWindow() {
        // approach 2 s, note at 10 s lasting 1 s.
        func visible(_ t: Double) -> Bool {
            HighwayGeometry.isVisible(noteTime: 10, duration: 1, songTime: t, approachTime: 2)
        }
        XCTAssertFalse(visible(7.9), "still more than one approach time away")
        XCTAssertTrue(visible(8.0))
        XCTAssertTrue(visible(10))
        XCTAssertTrue(visible(11.2), "a long note is still on screen after it starts")
        XCTAssertTrue(visible(11.3))
        XCTAssertFalse(visible(11.31), "gone once its end is 0.3 s behind the line")
    }

    func testLaneRectFollowsTheKeyFrameRelativeToTheHighway() {
        let keyFrame = CGRect(x: 300, y: 700, width: 60, height: 230)
        let rect = HighwayGeometry.noteRect(noteTime: 6, duration: 1, songTime: 5, approachTime: 2,
                                            hitY: 400, keyFrame: keyFrame, highwayOriginX: 100)
        XCTAssertEqual(rect.minX, 300 - 100 + 3)
        XCTAssertEqual(rect.width, 60 - 6)
        XCTAssertEqual(rect.height, 180)
        XCTAssertEqual(rect.maxY, 200, "bottom edge halfway to the line")
    }

    func testNarrowKeysNeverGiveANegativeWidth() {
        let rect = HighwayGeometry.noteRect(noteTime: 0, duration: 1, songTime: 0, approachTime: 2,
                                            hitY: 400, keyFrame: CGRect(x: 0, y: 0, width: 4, height: 10), highwayOriginX: 0)
        XCTAssertEqual(rect.width, 0)
    }
}

final class PlayModelsTests: XCTestCase {

    func testPlayRequestsAreHashableAndComparable() {
        let a = PlayRequest(kind: .song(songId: "x", mode: .perform, speed: 1, isBoss: false, isSolemn: false, noteLimit: nil))
        var b = a
        XCTAssertEqual(a, b)
        b.campaignStageId = "c1-04"
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(Set([a, b, a]).count, 2)
        XCTAssertNotEqual(PlayRequest(kind: .rush), PlayRequest(kind: .daily(dateKey: "20261009")))
    }

    func testRewardSummaryDefaultsToNothing() {
        let reward = RewardSummary()
        XCTAssertEqual(reward.coins, 0)
        XCTAssertEqual(reward.newStars, 0)
        XCTAssertFalse(reward.isNewBest)
        XCTAssertTrue(reward.newAchievements.isEmpty)
    }

    func testStageModesRoundTripThroughRawValues() {
        for mode in [StageMode.listen, .practice, .perform] {
            XCTAssertEqual(StageMode(rawValue: mode.rawValue), mode)
        }
    }

    func testRoutesCarryPlayRequests() {
        let request = PlayRequest(kind: .rush)
        XCTAssertEqual(Route.play(request), Route.play(request))
        XCTAssertNotEqual(Route.play(request), Route.help)
    }
}
