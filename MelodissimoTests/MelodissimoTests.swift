import XCTest
@testable import Melodissimo

/// Smoke test that proves the test bundle links against the app and runs on a simulator.
final class MelodissimoTests: XCTestCase {
    func testAppBundleLoads() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.balqishafiraini.Melodissimo")
    }
}
