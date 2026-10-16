import XCTest
@testable import Melodissimo

@MainActor
final class BootstrapServiceTests: XCTestCase {

    private var dir: URL!
    private var cacheURL: URL!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var playing = false
    private let api = URL(string: "https://api.test")!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("BootstrapServiceTests-\(UUID().uuidString)")
        cacheURL = dir.appendingPathComponent("Backend/bootstrap.json")
        clock = Date(timeIntervalSince1970: 1_800_000_000)
        playing = false
        LiveConfig.set(flags: [:], tuning: [:])
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        LiveConfig.set(flags: [:], tuning: [:])
        super.tearDown()
    }

    private func service(build: Int = 57, enabled: Bool = true) -> BootstrapService {
        BootstrapService(makeClient: { [api] in
                            APIClient(baseURL: api, session: StubURLProtocol.session(),
                                      headers: { ClientHeaders(version: "3.4.0", build: build, installId: "i", contentVersion: 0,
                                                               schemaVersion: 1, languages: [], storefront: "") })
                         },
                         cacheURL: cacheURL, build: build, now: { self.clock },
                         isPlaying: { self.playing }, isEnabled: { enabled })
    }

    private func body(minBuild: Int = 40, recommended: Int = 57, ttl: Int = 900, flags: String = #"{"shop": false}"#,
                      tuning: String = #"{"coins.dailyBase": 100}"#, maintenance: String = "null") -> Data {
        Data("""
        {"serverTime": "2026-10-15T08:00:00Z", "ttlSeconds": \(ttl),
         "update": {"action": "none", "policy": {"minSupportedBuild": \(minBuild), "recommendedBuild": \(recommended), "blockedBuilds": [52]}},
         "maintenance": \(maintenance), "flags": \(flags), "tuning": \(tuning)}
        """.utf8)
    }

    func testAFreshFetchIsPublishedCachedAndWiredIntoFlagsAndTuning() async throws {
        StubURLProtocol.handler = { _ in (200, self.body()) }
        let s = service()
        await s.refresh()
        XCTAssertEqual(s.current?.ttlSeconds, 900)
        XCTAssertEqual(s.directive, .none)
        XCTAssertEqual(LiveConfig.flags["shop"], false)
        XCTAssertEqual(LiveConfig.tuning["coins.dailyBase"], .number(100))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL.path))
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
        XCTAssertEqual(StubURLProtocol.requests.first?.url?.path, "/v1/bootstrap")
    }

    func testTheCacheRoundTripsAndANewServiceStartsFromIt() async throws {
        StubURLProtocol.handler = { _ in (200, self.body(maintenance: #"{"title": {"en": "Back soon"}, "blocksPlay": false}"#)) }
        await service().refresh()
        let again = service()
        XCTAssertNil(again.current)
        again.loadCached()
        XCTAssertEqual(again.current?.flags?["shop"], false)
        XCTAssertEqual(again.maintenance?.title?.resolved(preferred: ["en"]), "Back soon")
    }

    func testOfflineUsesTheCacheAndAHardPolicyStillBlocks() async throws {
        StubURLProtocol.handler = { _ in (200, self.body(minBuild: 60)) }   // this build (57) is below the minimum
        let first = service()
        await first.refresh()
        XCTAssertEqual(first.directive, .hard)

        StubURLProtocol.reset()   // no network any more
        let offline = service()
        offline.loadCached()
        XCTAssertEqual(offline.directive, .hard, "recomputed from the cached policy with no network")
        await offline.refresh(force: true)
        XCTAssertEqual(offline.directive, .hard, "a failed refresh keeps the cache")
        XCTAssertEqual(offline.current?.ttlSeconds, 900)
    }

    func testTheDirectiveFollowsTheBuildNotTheServersAction() async throws {
        StubURLProtocol.handler = { _ in (200, self.body(minBuild: 40, recommended: 60)) }
        let s = service(build: 57)
        await s.refresh()
        XCTAssertEqual(s.directive, .soft)
        let blocked = service(build: 52)
        await blocked.refresh(force: true)
        XCTAssertEqual(blocked.directive, .hard)
    }

    func testTheTTLIsRespectedAndForceOverridesIt() async throws {
        StubURLProtocol.handler = { _ in (200, self.body(ttl: 900)) }
        let s = service()
        await s.refresh()
        clock.addTimeInterval(899)
        await s.refresh()
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "still fresh")
        clock.addTimeInterval(2)
        await s.refresh()
        XCTAssertEqual(StubURLProtocol.requests.count, 2, "expired")
        await s.refresh(force: true)
        XCTAssertEqual(StubURLProtocol.requests.count, 3)
    }

    func testTheTTLAlsoCountsAfterARelaunch() async throws {
        StubURLProtocol.handler = { _ in (200, self.body(ttl: 900)) }
        await service().refresh()
        let relaunched = service()
        relaunched.loadCached()
        clock.addTimeInterval(60)
        await relaunched.refresh()
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testItNeverRefreshesWhileAPlayScreenIsOpen() async throws {
        StubURLProtocol.handler = { _ in (200, self.body()) }
        playing = true
        let s = service()
        await s.refresh(force: true)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
        playing = false
        await s.refresh()
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testTheFirstLaunchWaitsLessThanLaterOnes() async throws {
        StubURLProtocol.handler = { _ in (200, self.body()) }
        let s = service()
        await s.refresh()
        XCTAssertEqual(StubURLProtocol.requests.first?.timeoutInterval, BootstrapService.firstLaunchTimeout)
        await s.refresh(force: true)
        XCTAssertEqual(StubURLProtocol.requests.last?.timeoutInterval, BootstrapService.normalTimeout)
    }

    func testAnErrorAnswerOrGarbageChangesNothing() async throws {
        StubURLProtocol.handler = { _ in (503, Data(#"{"error": {"code": "not_ready"}}"#.utf8)) }
        let s = service()
        await s.refresh()
        XCTAssertNil(s.current)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
        StubURLProtocol.handler = { _ in (200, Data("garbage".utf8)) }
        await s.refresh()
        XCTAssertNil(s.current)
    }

    func testWhenTheBackendIsOffNothingHappens() async throws {
        StubURLProtocol.handler = { _ in (200, self.body()) }
        let s = service(enabled: false)
        s.start()
        await s.refresh(force: true)
        XCTAssertNil(s.current)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testWithoutAPolicyTheServersActionIsUsedAndUnknownMeansNoBlock() throws {
        func bootstrap(_ action: String) throws -> Bootstrap {
            try APIClient.makeDecoder().decode(Bootstrap.self, from: Data(
                #"{"serverTime": "2026-10-15T08:00:00Z", "ttlSeconds": 1, "update": {"action": "\#(action)"}}"#.utf8))
        }
        XCTAssertEqual(BootstrapService.directive(for: try bootstrap("hard"), build: 1), .hard)
        XCTAssertEqual(BootstrapService.directive(for: try bootstrap("soft"), build: 1), .soft)
        XCTAssertEqual(BootstrapService.directive(for: try bootstrap("banana"), build: 1), .none)
    }

    func testLiveConfigFeedsFeatureFlagsAndTuningByDefault() {
        LiveConfig.set(flags: ["shop": false], tuning: ["coins.dailyBase": .number(70)])
        FeatureFlags.source = { LiveConfig.flags }
        Tuning.source = { LiveConfig.tuning }
        XCTAssertFalse(FeatureFlags.isOn(.shop))
        XCTAssertEqual(Tuning.int("coins.dailyBase", default: 50), 70)
        LiveConfig.set(flags: [:], tuning: [:])
        XCTAssertTrue(FeatureFlags.isOn(.shop))
        XCTAssertEqual(Tuning.int("coins.dailyBase", default: 50), 50)
    }
}
