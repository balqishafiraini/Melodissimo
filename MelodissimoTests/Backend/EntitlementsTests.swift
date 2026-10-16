import XCTest
@testable import Melodissimo

final class ContentAccessTests: XCTestCase {

    private let packs: [ManifestPack] = {
        let json = """
        [{"id": "core", "title": {"en": "Core"}, "access": {"type": "free"}},
         {"id": "daerah-sumatra", "title": {"en": "Sumatra"}, "access": {"type": "product",
           "productIds": ["melodissimo.pack.daerah_sumatra", "melodissimo.plus.monthly", "melodissimo.plus.yearly"]}},
         {"id": "mystery", "title": {"en": "Mystery"}, "access": {"type": "somethingNew"}}]
        """
        return try! JSONDecoder().decode([ManifestPack].self, from: Data(json.utf8))
    }()

    private func unlocked(_ packId: String, _ owned: Set<String>) -> Bool {
        ContentAccess.isUnlocked(packId: packId, packs: packs, owned: owned)
    }

    func testTheFreePackIsAlwaysOpen() {
        XCTAssertTrue(unlocked("core", []))
        XCTAssertTrue(unlocked("core", ["melodissimo.plus.monthly"]))
    }

    func testTheAccessMatrixForAPaidPack() {
        XCTAssertFalse(unlocked("daerah-sumatra", []), "nothing owned")
        XCTAssertTrue(unlocked("daerah-sumatra", ["melodissimo.pack.daerah_sumatra"]), "the pack bought on its own")
        XCTAssertTrue(unlocked("daerah-sumatra", ["melodissimo.plus.monthly"]), "Plus active")
        XCTAssertTrue(unlocked("daerah-sumatra", ["melodissimo.plus.yearly"]))
        // Plus expired is simply "not owned" (Entitlements drops it): the pack bought separately stays open, the rest lock.
        XCTAssertTrue(unlocked("daerah-sumatra", ["melodissimo.pack.daerah_sumatra"]), "Plus expired, pack owned")
        XCTAssertFalse(unlocked("daerah-sumatra", ["melodissimo.coins.small"]), "an unrelated product opens nothing")
    }

    func testAnUnknownAccessTypeStaysLockedAndAMissingPackFollowsCore() {
        XCTAssertFalse(unlocked("mystery", ["melodissimo.plus.monthly"]))
        XCTAssertTrue(unlocked("core", []))
        XCTAssertFalse(unlocked("not-listed", []))
        XCTAssertTrue(ContentAccess.isUnlocked(packId: "anything", packs: [], owned: []), "a release without packs locks nobody out")
    }
}

final class EntitlementsTests: XCTestCase {

    private var suite = ""
    private var defaults: UserDefaults!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        suite = "EntitlementsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        clock = Date(timeIntervalSince1970: 1_800_000_000)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func entitlements() -> Entitlements { Entitlements(defaults: defaults, now: { self.clock }) }
    private func days(_ n: Double) -> Date { clock.addingTimeInterval(n * 86_400) }

    func testNothingOwnedByDefault() {
        let e = entitlements()
        XCTAssertTrue(e.ownedProductIds.isEmpty)
        XCTAssertEqual(e.plusStatus, .none)
        XCTAssertFalse(e.isPlusActive)
    }

    func testWhatStoreKitReportsIsOwnedAndCached() {
        let e = entitlements()
        e.apply(products: [OwnedProduct(productId: "melodissimo.pack.daerah_sumatra", expiresAt: nil),
                           OwnedProduct(productId: "melodissimo.plus.monthly", expiresAt: days(20))],
                plus: .active(renews: days(20)))
        XCTAssertEqual(e.ownedProductIds, ["melodissimo.pack.daerah_sumatra", "melodissimo.plus.monthly"])
        XCTAssertTrue(e.isPlusActive)

        let relaunched = entitlements()   // an offline launch reads the cache
        XCTAssertEqual(relaunched.ownedProductIds, e.ownedProductIds)
        XCTAssertEqual(relaunched.plusStatus, .active(renews: days(20)))
    }

    func testASubscriptionPastItsEndDateStopsCountingEvenOffline() {
        let e = entitlements()
        e.apply(products: [OwnedProduct(productId: "melodissimo.pack.daerah_sumatra", expiresAt: nil),
                           OwnedProduct(productId: "melodissimo.plus.monthly", expiresAt: days(10))],
                plus: .active(renews: days(10)))
        clock = days(11)
        let relaunched = entitlements()
        XCTAssertEqual(relaunched.ownedProductIds, ["melodissimo.pack.daerah_sumatra"], "the pack stays, Plus lapsed")
        XCTAssertEqual(relaunched.plusStatus, .expired)
        XCTAssertFalse(relaunched.isPlusActive)
    }

    func testGraceCountsAsActiveAndExpiredAndNoneDoNot() {
        XCTAssertTrue(PlusStatus.gracePeriod.isActive)
        XCTAssertTrue(PlusStatus.active(renews: nil).isActive)
        XCTAssertFalse(PlusStatus.expired.isActive)
        XCTAssertFalse(PlusStatus.none.isActive)
    }

    func testTheNewAnswerReplacesTheOldOne() {
        let e = entitlements()
        e.apply(products: [OwnedProduct(productId: "melodissimo.plus.yearly", expiresAt: days(300))], plus: .active(renews: days(300)))
        e.apply(products: [], plus: .none)   // refunded
        XCTAssertTrue(e.ownedProductIds.isEmpty)
        XCTAssertFalse(e.isPlusActive)
        XCTAssertTrue(entitlements().ownedProductIds.isEmpty)
    }

    func testUnlockingGoesThroughTheOwnedProducts() throws {
        let packs = try JSONDecoder().decode([ManifestPack].self, from: Data(
            #"[{"id": "p", "title": {"en": "P"}, "access": {"type": "product", "productIds": ["melodissimo.plus.monthly"]}}]"#.utf8))
        let e = entitlements()
        XCTAssertFalse(e.isUnlocked(packs[0]))
        e.apply(products: [OwnedProduct(productId: "melodissimo.plus.monthly", expiresAt: days(5))], plus: .active(renews: days(5)))
        XCTAssertTrue(e.isUnlocked(packs[0]))
        XCTAssertTrue(e.isUnlocked(packId: "p", packs: packs))
        clock = days(6)
        XCTAssertFalse(e.isUnlocked(packs[0]), "locked again once Plus has lapsed; nothing the player earned is deleted")
    }

    func testThePlusProductIdsAreRecognised() {
        XCTAssertTrue(Entitlements.isPlusProduct("melodissimo.plus.monthly"))
        XCTAssertTrue(Entitlements.isPlusProduct("melodissimo.plus.yearly"))
        XCTAssertFalse(Entitlements.isPlusProduct("melodissimo.pack.daerah_sumatra"))
    }

    func testThePlusMemberHookDrivesTheFreeRevive() {
        let original = Revive.isPlusMember
        defer { Revive.isPlusMember = original }
        let e = entitlements()
        Revive.isPlusMember = { e.isPlusActive }
        XCTAssertFalse(Revive.isPlusMember())
        e.apply(products: [OwnedProduct(productId: "melodissimo.plus.monthly", expiresAt: days(5))], plus: .active(renews: days(5)))
        XCTAssertTrue(Revive.isPlusMember())
    }
}
