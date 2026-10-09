import XCTest
@testable import Melodissimo

final class ShopCatalogTests: XCTestCase {

    func testIdsAreUniqueAndPrefixedByTheirCategory() {
        XCTAssertEqual(Set(ShopCatalog.items.map(\.id)).count, ShopCatalog.items.count)
        for item in ShopCatalog.items {
            XCTAssertTrue(item.id.hasPrefix(item.category.rawValue + "_"), item.id)
        }
    }

    func testEveryCategoryHasExactlyOneFreeDefault() {
        for category in ShopCategory.allCases {
            let defaults = ShopCatalog.items(in: category).filter(\.isDefault)
            XCTAssertEqual(defaults.count, 1, category.rawValue)
            XCTAssertEqual(ShopCatalog.defaultItem(for: category), defaults.first)
        }
    }

    func testPricesFollowThePlan() {
        let prices = Dictionary(uniqueKeysWithValues: ShopCatalog.items.map { ($0.id, $0.price) })
        XCTAssertEqual(prices["keyboard_batik"], 100)
        XCTAssertEqual(prices["keyboard_forest"], 150)
        XCTAssertEqual(prices["keyboard_sea"], 150)
        XCTAssertEqual(prices["keyboard_gold"], 300)
        XCTAssertEqual(prices["notes_rainbow"], 200)
        XCTAssertEqual(prices["notes_neon"], 250)
        XCTAssertEqual(prices["outfit_glasses"], 150)
        XCTAssertEqual(prices["outfit_crown"], 300)
        XCTAssertEqual(prices["outfit_royal"], 500)
    }

    func testTheWholeShopCostsAboutTwoThousandCoins() {
        let total = ShopCatalog.items.reduce(0) { $0 + $1.price }
        XCTAssertEqual(total, 2_100)
    }

    func testKeyboardSkinsCarryABodyAndAPressedColour() {
        for item in ShopCatalog.items(in: .keyboard) {
            XCTAssertEqual(item.colors.count, item.isDefault ? 0 : 2, item.id)
        }
    }

    func testOutfitVariantsMatchTheAlpanicaOutfitNames() {
        XCTAssertEqual(ShopCatalog.items(in: .outfit).map(\.variant), ["none", "glasses", "crown", "royal"])
        XCTAssertEqual(ShopCatalog.item(id: "keyboard_batik")?.variant, "batik")
    }

    func testLookupByIdAndCategory() {
        XCTAssertEqual(ShopCatalog.item(id: "notes_neon")?.name, "Neon")
        XCTAssertNil(ShopCatalog.item(id: "nope"))
        XCTAssertEqual(ShopCatalog.items(in: .notes).count, 3)
    }
}

final class NoteSkinTests: XCTestCase {

    func testTheStandardSkinKeepsTheNormalColours() {
        XCTAssertNil(NoteSkin.standard.fill(semitone: 7, isBlack: false))
        XCTAssertEqual(NoteSkin(itemId: "notes_default"), .standard)
        XCTAssertEqual(NoteSkin(itemId: "something-else"), .standard)
    }

    func testItemIdsPickTheirSkin() {
        XCTAssertEqual(NoteSkin(itemId: "notes_rainbow"), .rainbow)
        XCTAssertEqual(NoteSkin(itemId: "notes_neon"), .neon)
    }

    func testRainbowGivesEveryPitchClassItsOwnHue() throws {
        let hues = try (0..<12).map { try XCTUnwrap(NoteSkin.rainbow.fill(semitone: $0, isBlack: false)).hue }
        XCTAssertEqual(Set(hues).count, 12)
        XCTAssertTrue(hues.allSatisfy { $0 >= 0 && $0 < 1 })
    }

    func testRainbowRepeatsEveryOctave() throws {
        let low = try XCTUnwrap(NoteSkin.rainbow.fill(semitone: 4, isBlack: false))
        let high = try XCTUnwrap(NoteSkin.rainbow.fill(semitone: 16, isBlack: false))
        let higher = try XCTUnwrap(NoteSkin.rainbow.fill(semitone: 28, isBlack: false))
        XCTAssertEqual(low, high)
        XCTAssertEqual(low, higher)
    }

    func testRainbowBlackKeysAreDeeperThanWhiteOnesOfTheSameHue() throws {
        let white = try XCTUnwrap(NoteSkin.rainbow.fill(semitone: 3, isBlack: false))
        let black = try XCTUnwrap(NoteSkin.rainbow.fill(semitone: 3, isBlack: true))
        XCTAssertEqual(white.hue, black.hue)
        XCTAssertLessThan(black.brightness, white.brightness)
    }

    func testNeonSeparatesWhiteAndBlackKeys() throws {
        let white = try XCTUnwrap(NoteSkin.neon.fill(semitone: 0, isBlack: false))
        let black = try XCTUnwrap(NoteSkin.neon.fill(semitone: 1, isBlack: true))
        XCTAssertNotEqual(white.hue, black.hue)
        XCTAssertEqual(white, try XCTUnwrap(NoteSkin.neon.fill(semitone: 20, isBlack: false)), "neon ignores pitch")
    }

    func testRealPitchesNeverProduceInvalidColours() {
        for note in NoteCatalog.all {
            for skin in [NoteSkin.rainbow, .neon] {
                let fill = skin.fill(semitone: note.semitone, isBlack: note.isBlack)
                XCTAssertNotNil(fill)
                XCTAssertTrue((0...1).contains(fill?.hue ?? -1), "key \(note.id)")
            }
        }
    }
}

final class ShopPurchaseTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var progress: ProgressStore!

    override func setUp() {
        super.setUp()
        suiteName = "ShopPurchaseTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = ProgressStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func item(_ id: String) -> ShopItem { ShopCatalog.item(id: id)! }

    func testDefaultsAreOwnedAndWornFromTheStart() {
        for category in ShopCategory.allCases {
            let standard = ShopCatalog.defaultItem(for: category)
            XCTAssertTrue(progress.owns(standard))
            XCTAssertEqual(progress.equippedItem(category), standard)
        }
        XCTAssertEqual(progress.purchasedShopItemCount, 0)
    }

    func testBuyingTakesTheCoinsAndAddsTheItem() {
        progress.earn(500)
        XCTAssertTrue(progress.buy(item("keyboard_batik")))
        XCTAssertTrue(progress.owns(item("keyboard_batik")))
        XCTAssertEqual(progress.coinBalance, 400)
        XCTAssertEqual(progress.purchasedShopItemCount, 1)
        XCTAssertEqual(defaults.stringArray(forKey: "shop_owned"), ["keyboard_batik"])
    }

    func testYouCannotBuyWithoutEnoughCoins() {
        progress.earn(99)
        XCTAssertFalse(progress.buy(item("keyboard_batik")))
        XCTAssertFalse(progress.owns(item("keyboard_batik")))
        XCTAssertEqual(progress.coinBalance, 99)
        XCTAssertEqual(progress.purchasedShopItemCount, 0)
    }

    func testYouCannotBuyTheSameThingTwice() {
        progress.earn(1_000)
        XCTAssertTrue(progress.buy(item("outfit_crown")))
        XCTAssertFalse(progress.buy(item("outfit_crown")))
        XCTAssertEqual(progress.coinBalance, 700, "the second try cost nothing")
        XCTAssertEqual(defaults.stringArray(forKey: "shop_owned")?.count, 1)
    }

    func testADefaultCannotBeBought() {
        progress.earn(100)
        XCTAssertFalse(progress.buy(item("notes_default")))
        XCTAssertEqual(progress.coinBalance, 100)
    }

    func testEquippingNeedsOwnership() {
        XCTAssertFalse(progress.equip(item("notes_neon")))
        XCTAssertEqual(progress.equippedItem(.notes).id, "notes_default")

        progress.earn(250)
        progress.buy(item("notes_neon"))
        XCTAssertTrue(progress.equip(item("notes_neon")))
        XCTAssertEqual(progress.equippedItem(.notes).id, "notes_neon")
        XCTAssertEqual(defaults.string(forKey: "equip_notes"), "notes_neon")
    }

    func testCategoriesAreEquippedIndependently() {
        progress.earn(1_000)
        progress.buy(item("keyboard_gold"))
        progress.buy(item("outfit_glasses"))
        progress.equip(item("keyboard_gold"))
        progress.equip(item("outfit_glasses"))
        XCTAssertEqual(progress.equippedItem(.keyboard).id, "keyboard_gold")
        XCTAssertEqual(progress.equippedItem(.outfit).id, "outfit_glasses")
        XCTAssertEqual(progress.equippedItem(.notes).id, "notes_default")
    }

    func testGoingBackToTheDefaultAlwaysWorks() {
        progress.earn(300)
        progress.buy(item("keyboard_gold"))
        progress.equip(item("keyboard_gold"))
        XCTAssertTrue(progress.equip(item("keyboard_navy")))
        XCTAssertEqual(progress.equippedItem(.keyboard).id, "keyboard_navy")
    }

    func testAnUnknownOrUnownedEquippedIdFallsBackToTheDefault() {
        defaults.set("keyboard_gold", forKey: "equip_keyboard")   // never bought
        XCTAssertEqual(progress.equippedItem(.keyboard).id, "keyboard_navy")
        defaults.set("keyboard_removed", forKey: "equip_keyboard")
        XCTAssertEqual(progress.equippedItem(.keyboard).id, "keyboard_navy")
        defaults.set("notes_neon", forKey: "equip_keyboard")      // wrong category
        XCTAssertEqual(progress.equippedItem(.keyboard).id, "keyboard_navy")
    }

    func testWhatYouOwnSurvivesANewStore() {
        progress.earn(150)
        progress.buy(item("keyboard_sea"))
        progress.equip(item("keyboard_sea"))
        let again = ProgressStore(defaults: defaults)
        XCTAssertTrue(again.owns(item("keyboard_sea")))
        XCTAssertEqual(again.equippedItem(.keyboard).id, "keyboard_sea")
        XCTAssertEqual(again.coinBalance, 0)
    }
}
