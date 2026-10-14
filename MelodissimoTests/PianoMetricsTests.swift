import XCTest
@testable import Melodissimo

/// The keyboard heights: iPad keeps the v2 numbers exactly, iPhone gets short ones (IPHONE_PLAN §3.3).
final class PianoMetricsTests: XCTestCase {

    private func assertMetrics(_ metrics: PianoMetrics, white: CGFloat, black: CGFloat, container: CGFloat,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(metrics.whiteHeight, white, file: file, line: line)
        XCTAssertEqual(metrics.blackHeight, black, file: file, line: line)
        XCTAssertEqual(metrics.containerHeight, container, file: file, line: line)
        XCTAssertEqual(metrics.whiteRowHeight, container, "the white row is as tall as the container", file: file, line: line)
        XCTAssertEqual(metrics.blackRowHeight, white, "black keys line up with the tops of the white keys", file: file, line: line)
    }

    func testIPadNumbersAreTheV2Ones() {
        let full = PianoMetrics.make(.full, width: 1366, isPhone: false)
        assertMetrics(full, white: 350, black: 220, container: 450)
        XCTAssertEqual(full.whiteWidth, 65.568, accuracy: 1e-9)
        XCTAssertEqual(full.blackWidth, 57.372, accuracy: 1e-9)
        assertMetrics(PianoMetrics.make(.mini, width: 1366, isPhone: false), white: 200, black: 120, container: 300)
        assertMetrics(PianoMetrics.make(.stage, width: 1366, isPhone: false), white: 230, black: 145, container: 290)
    }

    func testIPhoneHeightsAreShort() {
        assertMetrics(PianoMetrics.make(.full, width: 734, isPhone: true), white: 150, black: 95, container: 170)
        assertMetrics(PianoMetrics.make(.mini, width: 734, isPhone: true), white: 110, black: 68, container: 125)
        assertMetrics(PianoMetrics.make(.stage, width: 734, isPhone: true), white: 120, black: 76, container: 136)
    }

    func testKeyWidthsFollowTheWidthItIsGiven() {
        // 15 Pro: 852 pt wide with 59 pt safe insets, so the keyboard gets 734 pt.
        let stage = PianoMetrics.make(.stage, width: 734, isPhone: true)
        XCTAssertEqual(stage.whiteWidth, 35.232, accuracy: 1e-9)
        let se = stage.resized(to: 667)
        XCTAssertEqual(se.whiteWidth, 32.016, accuracy: 1e-9, "about 32 pt on an iPhone SE")
        XCTAssertEqual(se.whiteHeight, stage.whiteHeight, "resizing keeps the heights")
        XCTAssertEqual(se.width, 667)
    }

    func testThirtyTwoKeysFitInsideTheWidth() {
        for width: CGFloat in [667, 734, 832, 1180, 1376] {
            let m = PianoMetrics.make(.stage, width: width, isPhone: width < 1000)
            // 19 white keys with a 2 pt gap between them.
            XCTAssertLessThan(19 * m.whiteWidth + 18 * 2, width, "white keys fit at \(width)")
        }
    }
}
