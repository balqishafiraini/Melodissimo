import XCTest
@testable import Melodissimo

final class PlusPricingTests: XCTestCase {

    func testTheYearlySavingIsWorkedOutFromTheTwoStorePrices() {
        // Rp 29.000 a month is Rp 348.000 a year; Rp 249.000 saves 28%.
        XCTAssertEqual(PlusPricing.yearlySavingPercent(monthly: 29_000, yearly: 249_000), 28)
        XCTAssertEqual(PlusPricing.yearlySavingPercent(monthly: Decimal(string: "4.99"), yearly: Decimal(string: "39.99")), 33)
        XCTAssertEqual(PlusPricing.yearlySavingPercent(monthly: 10, yearly: 60), 50)
    }

    func testNoSavingIsClaimedWhenThereIsNone() {
        XCTAssertNil(PlusPricing.yearlySavingPercent(monthly: 10, yearly: 120), "same as twelve months")
        XCTAssertNil(PlusPricing.yearlySavingPercent(monthly: 10, yearly: 150), "dearer")
        XCTAssertNil(PlusPricing.yearlySavingPercent(monthly: nil, yearly: 100))
        XCTAssertNil(PlusPricing.yearlySavingPercent(monthly: 10, yearly: nil))
        XCTAssertNil(PlusPricing.yearlySavingPercent(monthly: 0, yearly: 100))
        XCTAssertNil(PlusPricing.yearlySavingPercent(monthly: 10, yearly: 0))
    }

    func testTrialTextForDaysWeeksAndMonths() {
        XCTAssertEqual(PlusPricing.trialText(value: 7, unit: .day), String(format: NSLocalizedString("%lld days free", comment: ""), 7))
        XCTAssertEqual(PlusPricing.trialText(value: 1, unit: .weekOfYear), PlusPricing.trialText(value: 7, unit: .day))
        XCTAssertEqual(PlusPricing.trialText(value: 1, unit: .day), NSLocalizedString("1 day free", comment: ""))
        XCTAssertEqual(PlusPricing.trialText(value: 1, unit: .month), NSLocalizedString("1 month free", comment: ""))
        XCTAssertEqual(PlusPricing.trialText(value: 1, unit: .year), NSLocalizedString("Free trial", comment: ""))
    }

    func testLegalLinksStayHiddenWhileTheyArePlaceholders() {
        XCTAssertNil(LegalLinks.terms)
        XCTAssertNil(LegalLinks.privacy)
    }
}

final class PackStoreLogicTests: XCTestCase {

    func testAPackOnlyForSomeCountriesIsHiddenElsewhereButAnOwnedOneStays() throws {
        let pack = try JSONDecoder().decode(ManifestPack.self, from: Data(
            #"{"id": "daerah", "title": {"en": "D"}, "access": {"type": "product", "productIds": ["melodissimo.pack.d"]}, "markets": {"include": ["IDN", "MYS"], "featuredIn": ["IDN"]}}"#.utf8))
        XCTAssertTrue(Markets.allows(pack.markets, storefront: "IDN", deviceCountry: nil))
        XCTAssertFalse(Markets.allows(pack.markets, storefront: "JPN", deviceCountry: nil))
        XCTAssertTrue(Markets.allows(pack.markets, storefront: "JPN", deviceCountry: nil, isOwned: true))
        XCTAssertTrue(Markets.isFeatured(pack.markets, storefront: "IDN", deviceCountry: nil))
        XCTAssertFalse(Markets.isFeatured(pack.markets, storefront: "MYS", deviceCountry: nil))
    }

    func testSongsOfALockedPackAreLockedAndTheCoreIsNot() throws {
        let packs = try JSONDecoder().decode([ManifestPack].self, from: Data(
            #"[{"id": "core", "title": {"en": "C"}, "access": {"type": "free"}}, {"id": "p", "title": {"en": "P"}, "access": {"type": "product", "productIds": ["melodissimo.plus.monthly"]}}]"#.utf8))
        let core = Song(id: "a", title: "A", notationImage: "", keyIds: [5], isSolemn: false)
        let paid = Song(id: "b", title: "B", notationImage: "", packId: "p", keyIds: [5], isSolemn: false)
        XCTAssertTrue(ContentAccess.isUnlocked(packId: core.packId, packs: packs, owned: []))
        XCTAssertFalse(ContentAccess.isUnlocked(packId: paid.packId, packs: packs, owned: []))
        XCTAssertTrue(ContentAccess.isUnlocked(packId: paid.packId, packs: packs, owned: ["melodissimo.plus.monthly"]))
    }

    func testNoSolemnSongIsEverInAPaidPackInTheBaseline() {
        let store = ContentStore(root: FileManager.default.temporaryDirectory.appendingPathComponent("NoSolemn-\(UUID().uuidString)"))
        store.loadActive()
        let paidPackIds = Set(store.packs.filter { $0.access.type != "free" }.map(\.id))
        for song in store.songs where song.isSolemn { XCTAssertFalse(paidPackIds.contains(song.packId), song.id) }
        XCTAssertTrue(store.songs.allSatisfy { !$0.isSolemn || $0.packId == "core" })
    }
}
