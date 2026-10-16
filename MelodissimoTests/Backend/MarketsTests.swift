import XCTest
@testable import Melodissimo

final class MarketsTests: XCTestCase {

    private func markets(include: [String] = [], exclude: [String] = [], featured: [String] = []) -> Markets {
        Markets(include: include, exclude: exclude, featuredIn: featured)
    }

    func testNoMarketsMeansWorldwide() {
        XCTAssertTrue(Markets.allows(nil, storefront: "IDN", deviceCountry: nil))
        XCTAssertTrue(Markets.allows(markets(), storefront: "JPN", deviceCountry: nil))
        XCTAssertTrue(Markets.allows(nil, storefront: nil, deviceCountry: nil))
    }

    func testIncludeAndExclude() {
        let some = markets(include: ["IDN", "MYS", "SGP"])
        XCTAssertTrue(Markets.allows(some, storefront: "MYS", deviceCountry: nil))
        XCTAssertFalse(Markets.allows(some, storefront: "JPN", deviceCountry: nil))
        let notHere = markets(exclude: ["IDN"])
        XCTAssertFalse(Markets.allows(notHere, storefront: "IDN", deviceCountry: nil))
        XCTAssertTrue(Markets.allows(notHere, storefront: "MYS", deviceCountry: nil))
        XCTAssertFalse(Markets.allows(markets(include: ["IDN"], exclude: ["IDN"]), storefront: "IDN", deviceCountry: nil), "exclude wins")
    }

    func testAnUnknownStorefrontShowsWorldwideItemsAndItemsForTheDeviceRegion() {
        let idn = markets(include: ["IDN"])
        XCTAssertFalse(Markets.allows(idn, storefront: nil, deviceCountry: nil), "nothing to match: not shown")
        XCTAssertFalse(Markets.allows(idn, storefront: "", deviceCountry: nil))
        XCTAssertTrue(Markets.allows(idn, storefront: "", deviceCountry: "IDN"))
        XCTAssertFalse(Markets.allows(idn, storefront: "", deviceCountry: "JPN"))
        XCTAssertTrue(Markets.allows(nil, storefront: "", deviceCountry: nil))
    }

    func testAKnownStorefrontWinsOverTheDeviceRegion() {
        XCTAssertFalse(Markets.allows(markets(include: ["IDN"]), storefront: "MYS", deviceCountry: "IDN"))
    }

    func testWhatAPlayerOwnsStaysUsableInEveryCountry() {
        XCTAssertTrue(Markets.allows(markets(include: ["IDN"]), storefront: "JPN", deviceCountry: nil, isOwned: true))
        XCTAssertTrue(Markets.allows(markets(exclude: ["JPN"]), storefront: "JPN", deviceCountry: nil, isOwned: true))
    }

    func testFeaturedChangesOnlyTheOrder() {
        struct Item { let id: String; let markets: Markets? }
        let items = [Item(id: "a", markets: nil), Item(id: "b", markets: markets(featured: ["IDN"])), Item(id: "c", markets: nil),
                     Item(id: "d", markets: markets(featured: ["IDN", "MYS"]))]
        XCTAssertEqual(Markets.featuredFirst(items, markets: \.markets, storefront: "IDN", deviceCountry: nil).map(\.id), ["b", "d", "a", "c"])
        XCTAssertEqual(Markets.featuredFirst(items, markets: \.markets, storefront: "JPN", deviceCountry: nil).map(\.id), ["a", "b", "c", "d"])
        XCTAssertEqual(Markets.featuredFirst(items, markets: \.markets, storefront: "IDN", deviceCountry: nil).count, 4)
    }

    func testDeviceRegionsMapToAlpha3() {
        XCTAssertEqual(Market.alpha3(forRegion: "id"), "IDN")
        XCTAssertEqual(Market.alpha3(forRegion: "MY"), "MYS")
        XCTAssertNil(Market.alpha3(forRegion: "ZZ"))
        XCTAssertNil(Market.alpha3(forRegion: nil))
    }

    func testShopItemsAndProductsCarryMarkets() throws {
        let data = Data(#"{"items": [{"id": "keyboard_x", "category": "keyboard", "name": {"en": "X"}, "price": {"coins": 5}, "markets": {"include": ["MYS"], "featuredIn": ["MYS"]}}]}"#.utf8)
        let item = try XCTUnwrap(ShopCatalog.decode(data).first)
        XCTAssertEqual(item.markets?.include, ["MYS"])
        let product = try JSONDecoder().decode(StoreProduct.self, from: Data(#"{"id": "melodissimo.coins.x", "type": "consumable", "markets": {"exclude": ["IDN"]}}"#.utf8))
        XCTAssertEqual(product.markets?.exclude, ["IDN"])
    }

    func testTheShopHidesItemsOutsideTheirMarketButKeepsOwnedOnes() {
        var local = ShopItem(id: "keyboard_local", category: .keyboard, name: "Local", price: 50)
        local.markets = Markets(include: ["IDN"], exclude: nil, featuredIn: nil)
        var world = ShopItem(id: "keyboard_world", category: .keyboard, name: "World", price: 50)
        world.markets = Markets(include: nil, exclude: nil, featuredIn: ["MYS"])
        struct Fixed: ShopCatalogSource { let items: [ShopItem] }
        let original = ShopCatalog.source
        defer { ShopCatalog.source = original }
        ShopCatalog.source = Fixed(items: [ShopItem(id: "keyboard_navy", category: .keyboard, name: "Navy", price: 0), local, world])

        func ids(_ storefront: String, owned: Set<String> = []) -> [String] {
            ShopCatalog.visibleItems(in: .keyboard, owned: owned, build: 99, artIsAvailable: { _ in true },
                                     storefront: storefront, deviceCountry: nil).map(\.id)
        }
        XCTAssertEqual(ids("IDN"), ["keyboard_navy", "keyboard_local", "keyboard_world"])
        XCTAssertEqual(ids("JPN"), ["keyboard_navy", "keyboard_world"])
        XCTAssertEqual(ids("MYS"), ["keyboard_world", "keyboard_navy"], "featured in Malaysia: first")
        XCTAssertTrue(ids("JPN", owned: ["keyboard_local"]).contains("keyboard_local"), "owned stays")
    }

    func testCoinPacksFollowTheirMarkets() {
        let small = StoreProduct(id: "melodissimo.coins.small", type: "consumable", grants: PurchaseGrant(coins: 300))
        var idnOnly = StoreProduct(id: "melodissimo.coins.local", type: "consumable", grants: PurchaseGrant(coins: 100))
        idnOnly.markets = Markets(include: ["IDN"], exclude: nil, featuredIn: nil)
        ProductCatalog.override = [small, idnOnly]
        defer { ProductCatalog.override = nil }
        let ledger = PurchaseLedger(entries: [])
        XCTAssertEqual(ProductCatalog.consumablesOnSale(granted: ledger, storefront: "IDN", deviceCountry: nil).count, 2)
        XCTAssertEqual(ProductCatalog.consumablesOnSale(granted: ledger, storefront: "JPN", deviceCountry: nil).map(\.id), ["melodissimo.coins.small"])
    }
}
