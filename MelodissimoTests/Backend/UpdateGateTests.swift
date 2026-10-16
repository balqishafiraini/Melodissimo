import XCTest
@testable import Melodissimo

final class UpdateGateTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testASoftPromptShowsOnceThenWaitsThreeDays() {
        XCTAssertTrue(UpdateGate.shouldShowSoft(lastShown: nil, now: t0))
        XCTAssertFalse(UpdateGate.shouldShowSoft(lastShown: t0, now: t0.addingTimeInterval(3 * 24 * 3600 - 1)))
        XCTAssertTrue(UpdateGate.shouldShowSoft(lastShown: t0, now: t0.addingTimeInterval(3 * 24 * 3600)))
    }

    func testTheSoftPromptIsRememberedPerRecommendedBuild() {
        XCTAssertEqual(UpdateGate.softKey(recommendedBuild: 57), "backend_softUpdateShown_57")
        XCTAssertNotEqual(UpdateGate.softKey(recommendedBuild: 57), UpdateGate.softKey(recommendedBuild: 58))
    }

    func testTheBlockingScreenWaitsForASongToEnd() {
        XCTAssertTrue(UpdateGate.showsBlockingScreen(directive: .hard, isPlaying: false))
        XCTAssertFalse(UpdateGate.showsBlockingScreen(directive: .hard, isPlaying: true))
        XCTAssertFalse(UpdateGate.showsBlockingScreen(directive: .soft, isPlaying: false))
        XCTAssertFalse(UpdateGate.showsBlockingScreen(directive: .none, isPlaying: false))
    }

    func testMaintenanceTakesTheScreenOnlyWhenItBlocksPlayAndNoSongIsOn() {
        var info = Bootstrap.MaintenanceInfo(title: LocalizedText("Back soon"), message: nil, until: nil, blocksPlay: false)
        XCTAssertFalse(UpdateGate.showsMaintenanceScreen(info, isPlaying: false))
        info.blocksPlay = true
        XCTAssertTrue(UpdateGate.showsMaintenanceScreen(info, isPlaying: false))
        XCTAssertFalse(UpdateGate.showsMaintenanceScreen(info, isPlaying: true))
        XCTAssertFalse(UpdateGate.showsMaintenanceScreen(nil, isPlaying: false))
    }

    func testOnlyARealWebAddressOpensFromTheUpdateButton() {
        XCTAssertNotNil(UpdateGate.storeURL("https://apps.apple.com/app/id123"))
        XCTAssertNil(UpdateGate.storeURL("javascript:alert(1)"))
        XCTAssertNil(UpdateGate.storeURL("itms-apps://x"))
        XCTAssertNil(UpdateGate.storeURL(nil))
        XCTAssertNil(UpdateGate.storeURL(""))
    }

    func testServerTextsFollowTheLanguageAndFallBackToEnglish() {
        let info = Bootstrap.UpdateInfo(action: .hard, policy: nil, storeUrl: nil,
                                        title: LocalizedText(["en": "New version", "id": "Versi baru"]), message: nil)
        XCTAssertEqual(info.title?.resolved(preferred: ["id-ID"]), "Versi baru")
        XCTAssertEqual(info.title?.resolved(preferred: ["fr"]), "New version")
    }
}
