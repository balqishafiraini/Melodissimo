import XCTest
@testable import Melodissimo

final class PurchaseGrantsTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!

    private let medium = StoreProduct(id: "melodissimo.coins.medium", type: "consumable", grants: PurchaseGrant(coins: 1100))
    private let starter = StoreProduct(id: "melodissimo.bundle.starter", type: "consumable",
                                       grants: PurchaseGrant(coins: 500, items: ["boost_heart": 5]), oncePerPlayer: true)

    override func setUp() {
        super.setUp()
        suiteName = "PurchaseGrantsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testAGrantIsAppliedOnceEvenWhenDeliveredTwice() {
        XCTAssertTrue(PurchaseGrants.apply(transactionId: "1001", product: medium, to: progress))
        XCTAssertFalse(PurchaseGrants.apply(transactionId: "1001", product: medium, to: progress))
        XCTAssertEqual(progress.coinsPurchasedTotal, 1100)
        XCTAssertEqual(progress.coinBalance, 1100)
        XCTAssertEqual(defaults.stringArray(forKey: "iap_granted"), ["melodissimo.coins.medium:1001"])
    }

    func testTwoDifferentTransactionsBothPay() {
        PurchaseGrants.apply(transactionId: "1", product: medium, to: progress)
        PurchaseGrants.apply(transactionId: "2", product: medium, to: progress)
        XCTAssertEqual(progress.coinsPurchasedTotal, 2200)
    }

    func testABundleGrantsCoinsAndItems() {
        PurchaseGrants.apply(transactionId: "7", product: starter, to: progress)
        XCTAssertEqual(progress.coinsPurchasedTotal, 500)
        XCTAssertEqual(progress.inventoryCount("boost_heart"), 5)
    }

    func testAOncePerPlayerProductDisappearsAfterItsFirstPurchase() {
        ProductCatalog.products = [starter, medium]
        defer { ProductCatalog.override = nil }
        XCTAssertEqual(ProductCatalog.consumablesOnSale(granted: PurchaseGrants.ledger(in: progress)).map(\.id),
                       ["melodissimo.bundle.starter", "melodissimo.coins.medium"])
        PurchaseGrants.apply(transactionId: "7", product: starter, to: progress)
        XCTAssertEqual(ProductCatalog.consumablesOnSale(granted: PurchaseGrants.ledger(in: progress)).map(\.id),
                       ["melodissimo.coins.medium"])
    }

    func testAnItemNotInTheCatalogStaysInTheInventory() {
        let odd = StoreProduct(id: "melodissimo.bundle.odd", type: "consumable",
                               grants: PurchaseGrant(items: ["boost_unknown": 3]))
        PurchaseGrants.apply(transactionId: "9", product: odd, to: progress)
        XCTAssertNil(ShopCatalog.item(id: "boost_unknown"))
        XCTAssertEqual(progress.inventoryCount("boost_unknown"), 3)
    }

    func testPaidItemsAreNotCutOffByTheStackLimit() {
        let pile = StoreProduct(id: "melodissimo.bundle.pile", type: "consumable",
                                grants: PurchaseGrant(items: ["boost_heart": 150]))
        PurchaseGrants.apply(transactionId: "5", product: pile, to: progress)
        XCTAssertEqual(defaults.integer(forKey: "inv_gained_boost_heart"), 150)
    }

    func testProductsThatAreNotConsumablesOrGrantNothingAreIgnored() {
        let plus = StoreProduct(id: "melodissimo.plus.monthly", type: "autoRenewable", unlocks: ["pack:*"])
        let empty = StoreProduct(id: "melodissimo.coins.none", type: "consumable")
        XCTAssertFalse(PurchaseGrants.apply(transactionId: "3", product: plus, to: progress))
        XCTAssertFalse(PurchaseGrants.apply(transactionId: "4", product: empty, to: progress))
        XCTAssertNil(defaults.stringArray(forKey: "iap_granted"))
    }

    func testTheLedgerMatchesTransactionIdsExactly() {
        PurchaseGrants.apply(transactionId: "1001", product: medium, to: progress)
        let ledger = PurchaseGrants.ledger(in: progress)
        XCTAssertTrue(ledger.hasGranted(transactionId: "1001"))
        XCTAssertFalse(ledger.hasGranted(transactionId: "001"), "a longer id ending the same way is a different transaction")
        XCTAssertFalse(ledger.hasGranted(transactionId: "2001"))
    }

    // MARK: Bundled products

    func testTheBundledProductsAreTheCoinPacksAndTheStarterBundle() {
        let products = ProductCatalog.bundled()
        XCTAssertEqual(products.map(\.id), ["melodissimo.bundle.starter", "melodissimo.coins.small",
                                            "melodissimo.coins.medium", "melodissimo.coins.large"])
        XCTAssertEqual(products.map { $0.grants?.coins }, [500, 300, 1100, 3000])
        XCTAssertEqual(ProductCatalog.product(id: "melodissimo.bundle.starter")?.grants?.items["boost_heart"], 5)
        XCTAssertTrue(products.first { $0.id == "melodissimo.bundle.starter" }!.oncePerPlayer)
    }

    func testAnUnknownProductIdIsNotInTheCatalog() {
        XCTAssertNil(ProductCatalog.product(id: "melodissimo.future.thing"))
    }

    func testUnknownTypesAndBrokenEntriesAreKeptOrSkippedWithoutBreakingTheRest() {
        let data = Data("""
        {"products": [
          {"id": "melodissimo.plus.monthly", "type": "autoRenewable", "unlocks": ["pack:*"]},
          {"type": "consumable"},
          {"id": "melodissimo.coins.small", "type": "consumable", "grants": {"coins": 300}, "order": 1}
        ]}
        """.utf8)
        XCTAssertEqual(ProductCatalog.decode(data).map(\.id), ["melodissimo.plus.monthly", "melodissimo.coins.small"])
    }

    func testTheStoreKitConfigurationListsTheSameProductIds() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Melodissimo/Store/Products.storekit")
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let ids = (json["products"] as? [[String: Any]] ?? []).compactMap { $0["productID"] as? String }
        XCTAssertEqual(Set(ids), Set(ProductCatalog.bundled().map(\.id)))
    }
}
