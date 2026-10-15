import XCTest
import UIKit
@testable import Melodissimo

final class PlaySessionTests: XCTestCase {
    func testScreensOverlappingDuringATransitionKeepTheSessionOpen() {
        XCTAssertFalse(PlaySession.isActive)
        PlaySession.begin()                      // the new play screen appears …
        PlaySession.begin()                      // … before the old one has disappeared
        XCTAssertTrue(PlaySession.isActive)
        XCTAssertTrue(UIApplication.shared.isIdleTimerDisabled)
        PlaySession.end()
        XCTAssertTrue(PlaySession.isActive, "one play screen is still open")
        XCTAssertTrue(UIApplication.shared.isIdleTimerDisabled)
        PlaySession.end()
        XCTAssertFalse(PlaySession.isActive)
        XCTAssertFalse(UIApplication.shared.isIdleTimerDisabled)
    }

    func testAnExtraEndIsIgnored() {
        PlaySession.end()
        PlaySession.begin()
        XCTAssertTrue(PlaySession.isActive, "a stray end must not leave the counter negative")
        PlaySession.end()
        XCTAssertFalse(PlaySession.isActive)
    }

    func testTheObservableStateFollowsTheSession() {
        PlaySession.begin()
        XCTAssertTrue(PlaySessionState.shared.isActive)
        PlaySession.end()
        XCTAssertFalse(PlaySessionState.shared.isActive)
    }
}
