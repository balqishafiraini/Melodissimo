import XCTest
@testable import Melodissimo

final class ServerPurchasesTests: XCTestCase {

    private var suite = ""
    private var defaults: UserDefaults!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        suite = "ServerPurchasesTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        clock = Date(timeIntervalSince1970: 1_800_000_000)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func purchases(enabled: Bool = true) -> ServerPurchases {
        ServerPurchases(makeClient: { APIClient(baseURL: URL(string: "https://api.test"), session: StubURLProtocol.session(),
                                                headers: { ClientHeaders(version: "1", build: 1, installId: "i", contentVersion: 0, schemaVersion: 1, languages: [], storefront: "") },
                                                authorization: { "tok" }) },
                        isEnabled: { enabled })
    }

    func testReportingSendsTheSignedTransactionWithTheToken() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"ok": true, "granted": true}"#.utf8)) }
        let ok = await purchases().report(signedTransaction: "a.b.c")
        XCTAssertTrue(ok)
        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/purchases/apple")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
    }

    func testNothingIsSentWithoutAnAccount() async {
        StubURLProtocol.handler = { _ in (200, Data(#"{"ok": true}"#.utf8)) }
        let ok = await purchases(enabled: false).report(signedTransaction: "a.b.c")
        XCTAssertFalse(ok)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testARejectedReportIsNotFatal() async {
        StubURLProtocol.handler = { _ in (422, Data(#"{"error": {"code": "bad_transaction"}}"#.utf8)) }
        let ok = await purchases().report(signedTransaction: "bad")
        XCTAssertFalse(ok)
    }

    func testRefreshJoinsServerEntitlementsAndRestoresTheLedger() async {
        let json = """
        {"entitlements": [{"productId": "melodissimo.plus.yearly", "platform": "apple", "status": "active", "expiresAt": "2027-02-01T00:00:00Z"}],
         "ledger": {"coins": 1100, "items": {"boost_heart": 5}}}
        """
        StubURLProtocol.handler = { _ in (200, Data(json.utf8)) }
        let entitlements = Entitlements(defaults: defaults, now: { self.clock })
        let progress = ProgressStore(defaults: defaults)
        progress.addPurchasedCoins(50)
        let ok = await purchases().refresh(entitlements: entitlements, progress: progress)
        XCTAssertTrue(ok)
        XCTAssertTrue(entitlements.ownedProductIds.contains("melodissimo.plus.yearly"))
        XCTAssertTrue(entitlements.isPlusActive, "Plus bought on another device counts here")
        XCTAssertEqual(progress.coinsPurchasedTotal, 1100)
        XCTAssertEqual(progress.inventoryCount("boost_heart"), 5)
    }

    func testRestoringFromTheLedgerNeverLowersWhatThePlayerHas() async {
        StubURLProtocol.handler = { _ in (200, Data(#"{"entitlements": [], "ledger": {"coins": 100, "items": {"boost_heart": 1}}}"#.utf8)) }
        let progress = ProgressStore(defaults: defaults)
        progress.addPurchasedCoins(900)
        progress.addToInventory("boost_heart", count: 7)
        _ = await purchases().refresh(entitlements: Entitlements(defaults: defaults), progress: progress)
        XCTAssertEqual(progress.coinsPurchasedTotal, 900)
        XCTAssertEqual(progress.inventoryCount("boost_heart"), 7)
    }

    func testServerEntitlementsSurviveARelaunchAndLapseOnTheirEndDate() {
        let entitlements = Entitlements(defaults: defaults, now: { self.clock })
        entitlements.applyServer(products: [OwnedProduct(productId: "melodissimo.plus.monthly", expiresAt: clock.addingTimeInterval(86_400 * 10))])
        XCTAssertTrue(Entitlements(defaults: defaults, now: { self.clock }).isPlusActive)
        XCTAssertFalse(Entitlements(defaults: defaults, now: { self.clock.addingTimeInterval(86_400 * 11) }).isPlusActive)
    }

    func testAFailedRefreshKeepsWhatWasThere() async {
        StubURLProtocol.handler = { _ in (503, Data()) }
        let entitlements = Entitlements(defaults: defaults, now: { self.clock })
        entitlements.applyServer(products: [OwnedProduct(productId: "melodissimo.pack.daerah_sumatra", expiresAt: nil)])
        let ok = await purchases().refresh(entitlements: entitlements, progress: ProgressStore(defaults: defaults))
        XCTAssertFalse(ok)
        XCTAssertTrue(entitlements.ownedProductIds.contains("melodissimo.pack.daerah_sumatra"))
    }
}
