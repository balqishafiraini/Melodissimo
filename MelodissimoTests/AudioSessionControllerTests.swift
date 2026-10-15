import XCTest
import AVFoundation
@testable import Melodissimo

final class AudioSessionControllerTests: XCTestCase {
    func testInterruptionEventIsReadFromUserInfo() {
        XCTAssertEqual(AudioInterruptionEvent(userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]), .began)
        XCTAssertEqual(AudioInterruptionEvent(userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]), .ended)
    }

    func testInterruptionEventIgnoresMalformedUserInfo() {
        XCTAssertNil(AudioInterruptionEvent(userInfo: nil))
        XCTAssertNil(AudioInterruptionEvent(userInfo: [:]))
        XCTAssertNil(AudioInterruptionEvent(userInfo: [AVAudioSessionInterruptionTypeKey: "began"]))
    }

    func testRouteChangeReasonRoundTrips() {
        let note = Notification(name: AudioSessionController.routeChanged, object: nil,
                                userInfo: ["reason": AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        XCTAssertEqual(AudioSessionController.routeChangeReason(of: note), .oldDeviceUnavailable)
        XCTAssertNil(AudioSessionController.routeChangeReason(of: Notification(name: AudioSessionController.routeChanged)))
    }
}
