import CryptoKit
import XCTest
@testable import Melodissimo

private struct NoBaseline: ContentBaseline {
    var manifestData: Data? { nil }
    var signature: String? { nil }
    func assetURL(sha256: String, fileExtension: String) -> URL? { nil }
}

/// The shop and its products come from the content store, with the bundled files as the fallback (Task B6.4).
final class ShopFromContentTests: XCTestCase {

    private var dir: URL!
    private let key = Curve25519.Signing.PrivateKey()
    private var originalSource: ShopCatalogSource!

    override func setUpWithError() throws {
        originalSource = ShopCatalog.source
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ShopFromContent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        ShopCatalog.source = originalSource
        ProductCatalog.override = nil
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func store(shopJSON: String, productsJSON: String = "[]", assets: [String: Data] = [:]) throws -> ContentStore {
        let root = dir.appendingPathComponent("Content")
        let assetsDir = root.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        var assetJSON: [String] = []
        for (assetKey, data) in assets {
            let sha = ManifestVerifier.sha256Hex(of: data)
            try data.write(to: assetsDir.appendingPathComponent("\(sha).png"))
            assetJSON.append(#""\#(assetKey)": {"path": "assets/\#(sha).png", "sha256": "\#(sha)", "bytes": \#(data.count), "kind": "image"}"#)
        }
        let manifest = Data(#"{"schemaVersion": 1, "contentVersion": 4, "assets": {\#(assetJSON.joined(separator: ","))}, "shop": {"items": \#(shopJSON)}, "products": \#(productsJSON)}"#.utf8)
        let manifests = root.appendingPathComponent("manifests")
        try FileManager.default.createDirectory(at: manifests, withIntermediateDirectories: true)
        try manifest.write(to: manifests.appendingPathComponent("4.json"))
        try key.signature(for: manifest).base64EncodedString().write(to: manifests.appendingPathComponent("4.json.sig"), atomically: true, encoding: .utf8)
        try Data(#"{"version": 4}"#.utf8).write(to: root.appendingPathComponent("active.json"))
        let s = ContentStore(root: root, baseline: NoBaseline(),
                             verifier: ManifestVerifier(trustedKeys: [key.publicKey.rawRepresentation.base64EncodedString()]), build: { 57 })
        s.loadActive()
        return s
    }

    func testTheBundledBaselineGivesTheSameItemsAsTheBundledShopFile() {
        let baseline = ContentStore(root: dir.appendingPathComponent("Empty"))
        baseline.loadActive()
        XCTAssertEqual(baseline.manifestVersion, 0)
        let fromContent = ContentStoreShopSource(store: baseline).items
        let fromFile = BundledShopSource().items
        XCTAssertEqual(fromContent.map(\.id), fromFile.map(\.id))
        XCTAssertEqual(fromContent.map(\.price), fromFile.map(\.price))
        XCTAssertEqual(fromContent.map(\.colors), fromFile.map(\.colors))
        XCTAssertEqual(fromContent.map(\.category), fromFile.map(\.category))
    }

    func testAnEmptyStoreFallsBackToTheBundledFile() {
        let empty = ContentStore(root: dir.appendingPathComponent("None"), baseline: NoBaseline())
        XCTAssertEqual(ContentStoreShopSource(store: empty).items.map(\.id), BundledShopSource().items.map(\.id))
    }

    func testAReleaseCanAddAndRepriceItems() throws {
        let s = try store(shopJSON: #"""
        [{"id": "keyboard_batik", "category": "keyboard", "kind": "cosmetic", "name": {"en": "Batik"}, "price": {"coins": 80}, "order": 20},
         {"id": "keyboard_new", "category": "keyboard", "kind": "cosmetic", "name": {"en": "New"}, "price": {"coins": 120}, "colors": ["#112233", "#445566"], "order": 25},
         {"id": "hat_unknown", "category": "hat", "kind": "cosmetic", "name": {"en": "Hat"}, "price": {"coins": 5}}]
        """#)
        let items = ContentStoreShopSource(store: s).items
        XCTAssertEqual(items.first { $0.id == "keyboard_batik" }?.price, 80)
        XCTAssertEqual(items.first { $0.id == "keyboard_new" }?.colors, [0x112233, 0x445566])
        XCTAssertNil(items.first { $0.id == "hat_unknown" }, "an unknown category is skipped")
    }

    func testAnItemThatShippedWithTheAppNeverDisappearsAndStaysOwnedAndEquipped() throws {
        let s = try store(shopJSON: #"[{"id": "keyboard_new", "category": "keyboard", "kind": "cosmetic", "name": {"en": "New"}, "price": {"coins": 120}}]"#)
        ShopCatalog.source = ContentStoreShopSource(store: s)
        let suite = "ShopFromContent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["keyboard_gold"], forKey: "shop_owned")
        defaults.set("keyboard_gold", forKey: "equip_keyboard")
        let progress = ProgressStore(defaults: defaults)

        XCTAssertNotNil(ShopCatalog.item(id: "keyboard_gold"), "the release no longer lists it, the app still knows it")
        XCTAssertEqual(progress.equippedItem(.keyboard).id, "keyboard_gold")
        XCTAssertEqual(progress.purchasedShopItemCount, 1)
    }

    func testAnItemWhoseDownloadedArtHasNotArrivedIsHiddenNotBroken() throws {
        let hat = #"{"id": "outfit_topi", "category": "outfit", "kind": "cosmetic", "name": {"en": "Hat"}, "price": {"coins": 300}, "art": {"preview": "art.outfit_topi.preview", "overlay": "art.outfit_topi.overlay"}}"#
        let without = try store(shopJSON: "[\(hat)]")
        ShopCatalog.source = ContentStoreShopSource(store: without)
        let item = try XCTUnwrap(ShopCatalog.item(id: "outfit_topi"))
        XCTAssertFalse(ShopCatalog.hasArt(item, store: without))
        XCTAssertFalse(ShopCatalog.visibleItems(in: .outfit, owned: [], artIsAvailable: { ShopCatalog.hasArt($0, store: without) }).contains(item))
        XCTAssertEqual(ShopCatalog.artKeys(of: [item]), ["art.outfit_topi.preview", "art.outfit_topi.overlay"])

        try FileManager.default.removeItem(at: dir.appendingPathComponent("Content"))
        let with = try store(shopJSON: "[\(hat)]", assets: ["art.outfit_topi.preview": Data("p".utf8), "art.outfit_topi.overlay": Data("o".utf8)])
        ShopCatalog.source = ContentStoreShopSource(store: with)
        XCTAssertTrue(ShopCatalog.hasArt(item, store: with))
        XCTAssertTrue(ShopCatalog.visibleItems(in: .outfit, owned: [], artIsAvailable: { ShopCatalog.hasArt($0, store: with) }).contains { $0.id == "outfit_topi" })
        let outfit = AlpanicaOutfit(item: item, fileURL: { with.url(forAsset: $0) })
        guard case .file? = Optional(outfit.overlay ?? .asset("")) else { return XCTFail("downloaded art should be used") }
    }

    func testItemsWithBundledArtAreNeverHidden() {
        var bow = ShopItem(id: "outfit_bow", category: .outfit, name: "Bow", price: 100)
        bow.bundledArt = ShopArtNames(preview: "alpanica_outfit_bow", overlay: "alpanica_acc_bow")
        bow.art = ShopArtNames(preview: "art.never.arrives.preview", overlay: nil)
        XCTAssertTrue(ShopCatalog.hasArt(bow))
    }

    func testProductsComeFromTheReleaseAndFallBackToTheBundledFile() throws {
        let s = try store(shopJSON: "[]", productsJSON: #"[{"id": "melodissimo.plus.monthly", "type": "autoRenewable", "unlocks": ["pack:*"]}]"#)
        XCTAssertEqual(s.products.map(\.id), ["melodissimo.plus.monthly"])
        XCTAssertEqual(ProductCatalog.bundled().count, 7)
        ProductCatalog.override = nil
        XCTAssertFalse(ProductCatalog.products.isEmpty, "baseline or bundled products are always there")
    }
}
