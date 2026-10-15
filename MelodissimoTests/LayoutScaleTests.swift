import XCTest
@testable import Melodissimo

final class LayoutScaleTests: XCTestCase {

    func testPadReturnsEveryInputUnchanged() {
        let pad = LayoutScale.pad
        XCTAssertEqual(pad.s(220), 220)
        XCTAssertEqual(pad.s(0.5), 0.5)
        XCTAssertEqual(pad.f(40), 40)
        XCTAssertEqual(pad.f(15), 15)
        XCTAssertEqual(pad.f(0.5), 0.5)
        XCTAssertEqual(pad.tap(80), 80)
        XCTAssertEqual(pad.tap(10), 10, "iPad never raises a size to 44")
    }

    func testAnyPadShortSideIsThePadScale() {
        XCTAssertEqual(LayoutScale.make(isPhone: false, shortSide: 393), .pad)
        XCTAssertEqual(LayoutScale.make(isPhone: false, shortSide: 744), .pad)
        XCTAssertEqual(LayoutScale.make(isPhone: false, shortSide: 1032), .pad)
    }

    func testIPhone15ProScale() {
        let phone = LayoutScale.make(isPhone: true, shortSide: 393)
        XCTAssertTrue(phone.isPhone)
        XCTAssertEqual(phone.s(220), 105)
        XCTAssertEqual(phone.f(40), 26)
        XCTAssertEqual(phone.f(15), 13, "text never drops below 13 pt")
        XCTAssertEqual(phone.tap(80), 44, "a tap target never drops below 44 pt")
        XCTAssertEqual(phone.tap(200), 96)
    }

    func testStartingFactorsPerDevice() {
        XCTAssertEqual(LayoutScale.make(isPhone: true, shortSide: 375).size, 375.0 / 820, accuracy: 0.0001)
        XCTAssertEqual(LayoutScale.make(isPhone: true, shortSide: 440).size, 440.0 / 820, accuracy: 0.0001)
        XCTAssertEqual(LayoutScale.make(isPhone: true, shortSide: 375).font, 0.65)
    }

    func testSizeFactorIsClamped() {
        XCTAssertEqual(LayoutScale.make(isPhone: true, shortSide: 300).size, 0.44)
        XCTAssertEqual(LayoutScale.make(isPhone: true, shortSide: 600).size, 0.56)
    }
}
