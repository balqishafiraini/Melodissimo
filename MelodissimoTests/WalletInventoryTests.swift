import XCTest
@testable import Melodissimo

final class WalletInventoryTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!
    private let heart: ShopItem = {
        var item = ShopItem(id: "boost_heart", category: .boost, name: "Heart", price: 50)
        item.kind = .consumable
        return item
    }()

    override func setUp() {
        super.setUp()
        suiteName = "WalletInventoryTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: Wallet

    func testBalanceIsEarnedPlusPurchasedMinusSpent() {
        progress.earn(100)
        progress.addPurchasedCoins(300)
        XCTAssertTrue(progress.spend(150))
        XCTAssertEqual(progress.coinBalance, 250)
        XCTAssertEqual(defaults.integer(forKey: "coins_purchasedTotal"), 300)
    }

    func testPurchasedCoinsCanBeSpentAndNonPositiveGrantsAreIgnored() {
        progress.addPurchasedCoins(0)
        progress.addPurchasedCoins(-5)
        XCTAssertEqual(progress.coinsPurchasedTotal, 0)
        progress.addPurchasedCoins(60)
        XCTAssertTrue(progress.spend(60))
        XCTAssertEqual(progress.coinBalance, 0)
    }

    // MARK: Inventory

    func testCountIsGainedMinusUsedAndNeverNegative() {
        XCTAssertEqual(progress.inventoryCount("boost_heart"), 0)
        progress.addToInventory("boost_heart", count: 3)
        XCTAssertTrue(progress.useFromInventory("boost_heart"))
        XCTAssertEqual(progress.inventoryCount("boost_heart"), 2)
        XCTAssertEqual(defaults.integer(forKey: "inv_gained_boost_heart"), 3)
        XCTAssertEqual(defaults.integer(forKey: "inv_used_boost_heart"), 1)
    }

    func testUsingWithNoneLeftChangesNothing() {
        XCTAssertFalse(progress.useFromInventory("boost_heart"))
        XCTAssertNil(defaults.object(forKey: "inv_used_boost_heart"))
    }

    func testTheStackNeverGrowsPastItsMaximum() {
        XCTAssertEqual(progress.addToInventory("boost_heart", count: 8, maxStack: 5), 5)
        XCTAssertEqual(progress.addToInventory("boost_heart", count: 1, maxStack: 5), 0)
        XCTAssertEqual(progress.inventoryCount("boost_heart", maxStack: 5), 5)
    }

    func testBuyingPaysCoinsAndAddsToTheInventory() {
        progress.earn(120)
        XCTAssertTrue(progress.buyConsumable(heart, count: 2))
        XCTAssertEqual(progress.inventoryCount("boost_heart"), 2)
        XCTAssertEqual(progress.coinBalance, 20)
    }

    func testBuyingIsAllOrNothing() {
        progress.earn(120)
        XCTAssertFalse(progress.buyConsumable(heart, count: 3), "short of coins")
        XCTAssertFalse(progress.buyConsumable(heart, count: 3, maxStack: 2), "stack too small")
        XCTAssertFalse(progress.buyConsumable(heart, count: 0))
        XCTAssertEqual(progress.coinBalance, 120)
        XCTAssertEqual(progress.inventoryCount("boost_heart"), 0)
    }

    // MARK: Merge

    func testCoinsPurchasedAndInventoryTotalsMergeWithMaxAndTheLedgerWithUnion() {
        let titles: Set<String> = []
        XCTAssertEqual(CloudMerge.rule(for: "coins_purchasedTotal", songTitles: titles), .max)
        XCTAssertEqual(CloudMerge.rule(for: "inv_gained_boost_heart", songTitles: titles), .max)
        XCTAssertEqual(CloudMerge.rule(for: "inv_used_boost_heart", songTitles: titles), .max)
        XCTAssertEqual(CloudMerge.rule(for: "iap_granted", songTitles: titles), .union)
    }

    func testTwoDevicesThatBoughtAndUsedHeartsConvergeToTheRightCount() {
        // Both start from 5 gained / 1 used. A buys 5 more, B uses 2 more.
        let a: [String: Any] = ["inv_gained_boost_heart": 10, "inv_used_boost_heart": 1,
                                "iap_granted": ["t1"], "coins_purchasedTotal": 300]
        let b: [String: Any] = ["inv_gained_boost_heart": 5, "inv_used_boost_heart": 3,
                                "iap_granted": ["t2"], "coins_purchasedTotal": 300]
        let result = CloudMerge.merge(local: a, remote: b, songTitles: [])
        var aFinal = a, bFinal = b
        for (k, v) in result.local { aFinal[k] = v }
        for (k, v) in result.remote { bFinal[k] = v }
        for side in [aFinal, bFinal] {
            XCTAssertEqual(side["inv_gained_boost_heart"] as? Int, 10)
            XCTAssertEqual(side["inv_used_boost_heart"] as? Int, 3)
            XCTAssertEqual(side["iap_granted"] as? [String], ["t1", "t2"])
        }
    }

    // MARK: Reset

    func testResetKeepsWhatWasBoughtWithRealMoneyAndEmptiesEarnedCoins() {
        progress.earn(80)
        progress.addPurchasedCoins(300)
        progress.addToInventory("boost_heart", count: 4)
        defaults.set(["t1"], forKey: "iap_granted")

        progress.resetProgress()

        XCTAssertEqual(progress.coinsEarnedTotal, 0)
        XCTAssertEqual(progress.coinsPurchasedTotal, 300)
        XCTAssertEqual(progress.inventoryCount("boost_heart"), 4)
        XCTAssertEqual(defaults.stringArray(forKey: "iap_granted"), ["t1"])
        for key in ["coins_purchasedTotal", "inv_gained_boost_heart", "inv_used_boost_heart", "iap_granted"] {
            XCTAssertFalse(ProgressStore.isResettableKey(key, songTitles: []), key)
        }
    }
}
