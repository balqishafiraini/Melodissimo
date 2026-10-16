import XCTest
@testable import Melodissimo

/// The shop's stock lives in `Data/Shop/shop.json`. These tests pin it to the list the app shipped with.
final class ShopCatalogDataTests: XCTestCase {

    private struct FixedSource: ShopCatalogSource { let items: [ShopItem] }

    private var originalSource: ShopCatalogSource!

    override func setUp() {
        super.setUp()
        originalSource = ShopCatalog.source
    }

    override func tearDown() {
        ShopCatalog.source = originalSource
        super.tearDown()
    }

    /// The expected stock: id, price, colours. Never change an id, price or colour without a release plan.
    private let legacy: [(id: String, price: Int, colors: [UInt32])] = [
        ("keyboard_navy", 0, []), ("keyboard_batik", 100, [0x7B241C, 0xD35400]),
        ("keyboard_forest", 150, [0x145A32, 0x229954]), ("keyboard_sea", 150, [0x1A5276, 0x2E86C1]),
        ("keyboard_gold", 300, [0xB7950B, 0xD4AC0D]),
        ("notes_default", 0, []), ("notes_rainbow", 200, []), ("notes_neon", 250, []),
        ("outfit_none", 0, []), ("outfit_bow", 100, []), ("outfit_glasses", 150, []), ("outfit_headphones", 200, []),
        ("outfit_sunglasses", 200, []), ("outfit_scarf", 250, []), ("outfit_flowers", 250, []),
        ("outfit_crown", 300, []), ("outfit_blangkon", 350, []), ("outfit_conductor", 400, []),
        ("outfit_royal", 500, []),
    ]

    private func json(_ items: String) -> Data { Data("{\"items\": [\(items)]}".utf8) }

    private func item(_ id: String, _ category: String = "keyboard", price: Int = 10, extra: String = "") -> String {
        "{\"id\": \"\(id)\", \"category\": \"\(category)\", \"name\": {\"en\": \"X\"}, \"price\": {\"coins\": \(price)}\(extra)}"
    }

    // MARK: Bundled data

    func testTheBundledCatalogHasTheSameIdsPricesAndColoursAsBefore() {
        XCTAssertEqual(ShopCatalog.items.map(\.id), legacy.map(\.id))
        XCTAssertEqual(ShopCatalog.items.map(\.price), legacy.map(\.price))
        XCTAssertEqual(ShopCatalog.items.map(\.colors), legacy.map(\.colors))
        XCTAssertTrue(ShopCatalog.items.allSatisfy { $0.kind == .cosmetic && $0.status == .live })
    }

    func testDefaultsAreNamedInBothLanguages() {
        let navy = ShopCatalog.item(id: "outfit_none")!
        XCTAssertEqual(navy.names.resolved(preferred: ["id"]), "Bawaan")
        XCTAssertEqual(navy.names.resolved(preferred: ["en"]), "Default")
        XCTAssertEqual(ShopCatalog.item(id: "keyboard_batik")?.names.resolved(preferred: ["id"]), "Merah Batik")
    }

    // MARK: Decoding

    func testAnUnknownCategoryKindOrStatusSkipsOnlyThatItem() {
        let data = json([
            item("keyboard_a"),
            item("hat_b", "hat"),
            item("keyboard_c", extra: ", \"kind\": \"mystery\""),
            item("keyboard_d", extra: ", \"status\": \"archived\""),
            item("keyboard_e"),
        ].joined(separator: ","))
        XCTAssertEqual(ShopCatalog.decode(data).map(\.id), ["keyboard_a", "keyboard_e"])
    }

    func testABrokenFieldSkipsTheItemAndGarbageGivesAnEmptyCatalog() {
        let data = json([item("keyboard_a", extra: ", \"colors\": [\"red\"]"), item("keyboard_b")].joined(separator: ","))
        XCTAssertEqual(ShopCatalog.decode(data).map(\.id), ["keyboard_b"])
        XCTAssertTrue(ShopCatalog.decode(Data("nope".utf8)).isEmpty)
    }

    func testOptionalFieldsDecode() {
        let data = json(item("boost_heart", "boost", extra: """
            , "kind": "consumable", "maxStack": 99, "tags": ["new"], "plusOnly": true, "order": 300, "minAppBuild": 60,
            "bundledArt": {"preview": "icon_heart"}, "availableFrom": "2026-11-01T00:00:00Z", "availableUntil": null
            """))
        let heart = ShopCatalog.decode(data)[0]
        XCTAssertEqual(heart.kind, .consumable)
        XCTAssertEqual(heart.maxStack, 99)
        XCTAssertEqual(heart.tags, ["new"])
        XCTAssertTrue(heart.plusOnly)
        XCTAssertEqual(heart.order, 300)
        XCTAssertEqual(heart.minAppBuild, 60)
        XCTAssertEqual(heart.bundledArt?.preview, "icon_heart")
        XCTAssertEqual(heart.availableFrom, ISO8601DateFormatter().date(from: "2026-11-01T00:00:00Z"))
        XCTAssertNil(heart.availableUntil)
        XCTAssertFalse(heart.isDefault)
    }

    func testItemsFollowTheOrderField() {
        let data = json([item("keyboard_b", extra: ", \"order\": 20"), item("keyboard_a", extra: ", \"order\": 10")].joined(separator: ","))
        ShopCatalog.source = FixedSource(items: ShopCatalog.decode(data))
        XCTAssertEqual(ShopCatalog.items.map(\.id), ["keyboard_a", "keyboard_b"])
    }

    // MARK: Filters

    func testOnlyLiveItemsBuiltForThisAppInsideTheirWindowAreOnSale() {
        let now = ISO8601DateFormatter().date(from: "2026-11-15T00:00:00Z")!
        let items = ShopCatalog.decode(json([
            item("keyboard_live"),
            item("keyboard_hidden", extra: ", \"status\": \"hidden\""),
            item("keyboard_soon", extra: ", \"status\": \"comingSoon\""),
            item("keyboard_future", extra: ", \"minAppBuild\": 99"),
            item("keyboard_early", extra: ", \"availableFrom\": \"2026-12-01T00:00:00Z\""),
            item("keyboard_ended", extra: ", \"availableUntil\": \"2026-11-01T00:00:00Z\""),
            item("keyboard_open", extra: ", \"availableFrom\": \"2026-11-01T00:00:00Z\", \"availableUntil\": \"2026-12-01T00:00:00Z\""),
        ].joined(separator: ",")))
        let onSale = items.filter { ShopCatalog.isOnSale($0, now: now, build: 57) }.map(\.id)
        XCTAssertEqual(onSale, ["keyboard_live", "keyboard_open"])
    }

    func testAnOwnedItemStaysVisibleAndWornAfterItsWindowEnds() {
        let suite = "ShopCatalogDataTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ProgressStore(defaults: defaults)
        ShopCatalog.source = FixedSource(items: ShopCatalog.decode(json([
            item("keyboard_navy", price: 0),
            item("keyboard_old", extra: ", \"availableUntil\": \"2020-01-01T00:00:00Z\", \"status\": \"hidden\""),
        ].joined(separator: ","))))
        let old = ShopCatalog.item(id: "keyboard_old")!

        XCTAssertFalse(ShopCatalog.visibleItems(in: .keyboard, owned: []).contains(old), "not for sale, not owned")
        progress.earn(100)
        defaults.set(["keyboard_old"], forKey: "shop_owned")
        XCTAssertTrue(ShopCatalog.visibleItems(in: .keyboard, owned: ["keyboard_old"]).contains(old))
        XCTAssertTrue(progress.equip(old))
        XCTAssertEqual(progress.equippedItem(.keyboard), old)
        XCTAssertEqual(progress.purchasedShopItemCount, 1)
    }

    func testACategoryWithNothingToShowGetsNoTab() {
        XCTAssertEqual(ShopCatalog.visibleCategories(owned: []), [.keyboard, .notes, .outfit])
    }

    func testTheCatalogFallsBackToAFreeDefaultWhenItCannotBeRead() {
        ShopCatalog.source = FixedSource(items: [])
        for category in ShopCategory.equippable {
            XCTAssertEqual(ShopCatalog.defaultItem(for: category).price, 0)
            XCTAssertEqual(ShopCatalog.defaultItem(for: category).category, category)
        }
    }

    func testAConsumableCannotBeBoughtLikeACosmetic() {
        let suite = "ShopCatalogDataTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ProgressStore(defaults: defaults)
        progress.earn(500)
        var heart = ShopItem(id: "boost_heart", category: .boost, name: "Heart", price: 50)
        heart.kind = .consumable
        XCTAssertFalse(progress.buy(heart))
        XCTAssertEqual(progress.coinBalance, 500)
    }
}

final class LocalizedTextTests: XCTestCase {

    private let text = LocalizedText(["en": "Bow", "id": "Pita", "pt": "Laço"])

    func testTheFirstPreferredLanguageWithATextWins() {
        XCTAssertEqual(text.resolved(preferred: ["id-ID", "en"]), "Pita")
    }

    func testARegionFallsBackToItsLanguage() {
        XCTAssertEqual(text.resolved(preferred: ["pt-BR"]), "Laço")
        XCTAssertEqual(LocalizedText(["pt-BR": "Fita", "pt": "Laço", "en": "Bow"]).resolved(preferred: ["pt-BR"]), "Fita")
    }

    func testAnUnknownLanguageFallsBackToEnglishThenToAnything() {
        XCTAssertEqual(text.resolved(preferred: ["ja-JP"]), "Bow")
        XCTAssertEqual(LocalizedText(["ms": "Reben", "id": "Pita"]).resolved(preferred: ["ja"]), "Pita")
        XCTAssertEqual(LocalizedText([:]).resolved(preferred: ["en"]), "")
    }

    func testItRoundTripsAsAPlainDictionary() throws {
        let data = try JSONEncoder().encode(text)
        XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: data), text.values)
        XCTAssertEqual(try JSONDecoder().decode(LocalizedText.self, from: data), text)
    }
}
