import XCTest
@testable import Melodissimo

final class AnalyticsTests: XCTestCase {

    private var dir: URL!
    private var fileURL: URL!
    private var enabled = true
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("AnalyticsTests-\(UUID().uuidString)")
        fileURL = dir.appendingPathComponent("Backend/events.json")
        enabled = true
        clock = Date(timeIntervalSince1970: 1_800_000_000)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func analytics() -> Analytics {
        Analytics(fileURL: fileURL,
                  makeClient: { APIClient(baseURL: URL(string: "https://api.test"), session: StubURLProtocol.session(),
                                          headers: { ClientHeaders(version: "1", build: 1, installId: "i", contentVersion: 0, schemaVersion: 1, languages: [], storefront: "") }) },
                  isEnabled: { self.enabled }, installId: { "install" }, now: { self.clock })
    }

    /// Waits until the stub has seen `count` requests (the flush runs on a task).
    private func waitForRequests(_ count: Int) async {
        for _ in 0..<100 where StubURLProtocol.requests.count < count { try? await Task.sleep(nanoseconds: 20_000_000) }
    }

    func testNothingIsRecordedWhileAnalyticsIsOff() {
        enabled = false
        let a = analytics()
        a.log(.appOpen)
        a.waitUntilIdle()
        XCTAssertEqual(a.bufferedCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testEventsAreBufferedToDiskAndSurviveARelaunch() {
        let a = analytics()
        a.log(.stageEnd, props: ["songId": "halo-halo-bandung", "stars": 3, "won": true])
        a.waitUntilIdle()
        XCTAssertEqual(a.bufferedCount, 1)
        let relaunched = analytics()
        XCTAssertEqual(relaunched.bufferedCount, 1)
    }

    func testFlushSendsABatchWithIsoDatesAndClearsTheBuffer() async throws {
        StubURLProtocol.handler = { _ in (202, Data(#"{"ok": true, "accepted": 2}"#.utf8)) }
        let a = analytics()
        a.log(.appOpen)
        a.log(.paywallView, props: ["packId": "daerah-sumatra"])
        a.flush()
        await waitForRequests(1)
        a.waitUntilIdle()
        XCTAssertEqual(a.bufferedCount, 0)
        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/events")
        let body = try XCTUnwrap(request.bodyStreamData() ?? request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let events = try XCTUnwrap(json["events"] as? [[String: Any]])
        XCTAssertEqual(events.map { $0["name"] as? String }, ["app_open", "paywall_view"])
        XCTAssertEqual(events[0]["at"] as? String, "2027-01-15T08:00:00Z")
        XCTAssertEqual((events[1]["props"] as? [String: Any])?["packId"] as? String, "daerah-sumatra")
        XCTAssertNil(events[0]["install"], "no identifiers in the body: the install id travels as a header")
    }

    func testAFailedSendKeepsTheEvents() async throws {
        StubURLProtocol.handler = { _ in (503, Data()) }
        let a = analytics()
        a.log(.appOpen)
        a.flush()
        await waitForRequests(1)
        a.waitUntilIdle()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(a.bufferedCount, 1)
    }

    func testTwentyEventsTriggerAFlushAutomatically() async throws {
        StubURLProtocol.handler = { _ in (202, Data(#"{"ok": true}"#.utf8)) }
        let a = analytics()
        for _ in 0..<Analytics.flushThreshold { a.log(.stageStart) }
        await waitForRequests(1)
        XCTAssertGreaterThanOrEqual(StubURLProtocol.requests.count, 1)
    }

    func testTheBufferIsCapped() {
        let a = analytics()
        enabled = true
        // Offline: sends fail, so nothing leaves the buffer.
        StubURLProtocol.handler = { _ in (503, Data()) }
        for index in 0..<(Analytics.maxBuffered + 30) { a.log(.stageStart, props: ["n": .number(Double(index))]) }
        a.waitUntilIdle()
        XCTAssertLessThanOrEqual(a.bufferedCount, Analytics.maxBuffered)
    }

    func testTheEventNamesAreTheOnesTheServerAccepts() throws {
        let schema = try JSONSerialization.jsonObject(with: fixtureData("events-names")) as? [String: Any]
        let names = Set(try XCTUnwrap(schema?["names"] as? [String]))
        XCTAssertEqual(Set(AnalyticsEvent.allCases.map(\.rawValue)), names)
    }

    func testTheDefaultSwitchNeedsTheFlagTheBackendAndTheSample() {
        FeatureFlags.source = { [:] }
        XCTAssertFalse(Analytics.defaultIsEnabled(), "off by default")
        FeatureFlags.source = { LiveConfig.flags }
    }
}

private extension URLRequest {
    /// URLProtocol receives the body as a stream.
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

final class AnalyticsPropsTests: XCTestCase {

    func testPlayRequestsGiveCoarsePropsOnly() {
        let song = PlayRequest(kind: .song(songId: "halo-halo-bandung", mode: .perform, speed: 1, isBoss: false, isSolemn: false, noteLimit: nil),
                               campaignStageId: "c1-03")
        XCTAssertEqual(song.analyticsProps, ["mode": "perform", "songId": "halo-halo-bandung", "stageId": "c1-03"])
        XCTAssertEqual(PlayRequest(kind: .rush).analyticsProps, ["mode": "rush"])
        XCTAssertEqual(PlayRequest(kind: .classic(levelNo: 4)).analyticsMode, "classic")
        XCTAssertEqual(PlayRequest(kind: .daily(dateKey: "20261016")).analyticsMode, "daily")
    }

    func testJSONValueLiteralsMakePropsEasyToWrite() {
        let props: [String: JSONValue] = ["songId": "x", "stars": 3, "ratio": 0.5, "won": true]
        XCTAssertEqual(props["stars"], .number(3))
        XCTAssertEqual(props["won"], .bool(true))
        XCTAssertEqual(props["songId"], .string("x"))
    }
}
