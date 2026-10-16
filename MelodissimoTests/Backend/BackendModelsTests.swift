import XCTest
@testable import Melodissimo

final class BackendModelsTests: XCTestCase {

    override func tearDown() {
        Tuning.source = { [:] }
        FeatureFlags.source = { [:] }
        super.tearDown()
    }

    // MARK: Shared vectors

    private struct RolloutVectors: Decodable {
        struct Row: Decodable { let installId: String; let key: String; let bucket: Int }
        let vectors: [Row]
    }

    func testTheRolloutBucketMatchesTheServersVectors() throws {
        let vectors = try JSONDecoder().decode(RolloutVectors.self, from: fixtureData("rollout-vectors")).vectors
        XCTAssertEqual(vectors.count, 20)
        for v in vectors {
            XCTAssertEqual(RolloutBucket.bucket(installId: v.installId, key: v.key), v.bucket, "\(v.installId):\(v.key)")
        }
        XCTAssertEqual(RolloutBucket.fnv1a32(""), 0x811c9dc5)
        XCTAssertEqual(RolloutBucket.fnv1a32("a"), 0xe40c292c)
        XCTAssertEqual(RolloutBucket.fnv1a32("foobar"), 0xbf9cf968)
    }

    private struct PolicyVectors: Decodable {
        struct Row: Decodable { let build: Int; let policy: Bootstrap.UpdatePolicy; let action: String }
        let vectors: [Row]
    }

    func testTheUpdateDirectiveMatchesTheServersVectors() throws {
        let vectors = try JSONDecoder().decode(PolicyVectors.self, from: fixtureData("update-policy-vectors")).vectors
        XCTAssertGreaterThanOrEqual(vectors.count, 12)
        for v in vectors {
            XCTAssertEqual(UpdateDirective.decide(build: v.build, policy: v.policy).rawValue, v.action, "build \(v.build)")
        }
        XCTAssertEqual(Set(vectors.map(\.action)), ["none", "soft", "hard"])
    }

    // MARK: Bootstrap

    func testTheBootstrapExampleDecodesFully() throws {
        let b = try APIClient.makeDecoder().decode(Bootstrap.self, from: fixtureData("bootstrap"))
        XCTAssertEqual(b.ttlSeconds, 900)
        XCTAssertEqual(b.update?.action, Bootstrap.Action.none)
        XCTAssertEqual(b.update?.policy, Bootstrap.UpdatePolicy(minSupportedBuild: 40, recommendedBuild: 57, blockedBuilds: [52]))
        XCTAssertEqual(b.update?.title?.resolved(preferred: ["id"]), "Versi baru tersedia")
        XCTAssertNil(b.maintenance)
        XCTAssertEqual(b.flags?["shop"], true)
        XCTAssertEqual(b.flags?["micInput"], false)
        XCTAssertEqual(b.tuning?["coins.dailyBase"], .number(50))
        XCTAssertEqual(b.content?.version, 12)
        XCTAssertEqual(b.announcements?.first?.id, "merdeka-2026")
        XCTAssertEqual(b.announcements?.first?.route, "freePlay")
    }

    func testOnlyServerTimeAndTtlAreRequiredAndUnknownThingsAreIgnored() throws {
        let json = #"{"serverTime": "2026-10-15T08:00:00Z", "ttlSeconds": 60, "somethingNew": {"a": 1}, "update": {"action": "banana", "extra": 1}}"#
        let b = try APIClient.makeDecoder().decode(Bootstrap.self, from: Data(json.utf8))
        XCTAssertEqual(b.update?.action, .unknown)
        XCTAssertNil(b.flags)
        XCTAssertNil(b.content)
        XCTAssertThrowsError(try APIClient.makeDecoder().decode(Bootstrap.self, from: Data(#"{"ttlSeconds": 1}"#.utf8)))
    }

    func testABootstrapSurvivesARoundTripThroughTheDiskCacheFormat() throws {
        let b = try APIClient.makeDecoder().decode(Bootstrap.self, from: fixtureData("bootstrap"))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let again = try APIClient.makeDecoder().decode(Bootstrap.self, from: encoder.encode(b))
        XCTAssertEqual(again, b)
    }

    func testJSONValueHoldsAnyShape() throws {
        let v = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"a": [1, "x", true, null], "b": {"c": 2.5}}"#.utf8))
        XCTAssertEqual(v, .object(["a": .array([.number(1), .string("x"), .bool(true), .null]), "b": .object(["c": .number(2.5)])]))
    }

    // MARK: Flags

    func testMissingFlagsFallBackToTheCodeDefaults() {
        FeatureFlags.source = { [:] }
        XCTAssertTrue(FeatureFlags.isOn(.shop))
        XCTAssertTrue(FeatureFlags.isOn(.dailyChallenge))
        XCTAssertTrue(FeatureFlags.isOn(.micInput))
        XCTAssertTrue(FeatureFlags.isOn(.coinStore))
        XCTAssertFalse(FeatureFlags.isOn(.reviveInDaily))
        XCTAssertFalse(FeatureFlags.isOn(.packStore))
    }

    func testServerFlagsOverrideTheDefaultsInBothDirections() {
        FeatureFlags.source = { ["shop": false, "packStore": true, "unknownFlag": true] }
        XCTAssertFalse(FeatureFlags.isOn(.shop))
        XCTAssertTrue(FeatureFlags.isOn(.packStore))
        XCTAssertTrue(FeatureFlags.isOn(.dailyChallenge))
    }

    // MARK: Tuning

    func testTuningReturnsAValidServerValue() {
        Tuning.source = { ["coins.dailyBase": .number(100)] }
        XCTAssertEqual(Tuning.int("coins.dailyBase", default: 50), 100)
    }

    func testAMalformedTuningValueFallsBackToTheDefault() {
        Tuning.source = {
            ["a": .string("100"), "b": .number(2.5), "c": .number(-5), "d": .number(2_000_000), "e": .null, "f": .bool(true)]
        }
        for key in ["a", "b", "c", "d", "e", "f", "missing"] {
            XCTAssertEqual(Tuning.int(key, default: 7), 7, key)
        }
        XCTAssertEqual(Tuning.int("d", default: 7, range: 0...3_000_000), 2_000_000)
        XCTAssertEqual(Tuning.double("b", default: 1), 2.5)
        XCTAssertEqual(Tuning.double("c", default: 1), 1, "outside the default range")
        XCTAssertTrue(Tuning.bool("f", default: false))
        XCTAssertFalse(Tuning.bool("a", default: false))
    }

    func testCoinRewardsFollowTheServerAndFallBackOffline() {
        XCTAssertEqual(CoinRewards.daily(streak: 3), 80)
        Tuning.source = { ["coins.dailyBase": .number(100), "coins.dailyPerStreakDay": .number(20), "coins.dailyStreakCap": .number(2)] }
        XCTAssertEqual(CoinRewards.daily(streak: 3), 140)
        Tuning.source = { ["coins.perNewStar": .number(25), "coins.firstClear": .number(40)] }
        XCTAssertEqual(CoinRewards.clear(newStars: 2, isFirstStageClear: true, isFirstBossClear: false), 90)
        Tuning.source = { ["coins.rushAnswersPerCoin": .number(0)] }
        XCTAssertEqual(CoinRewards.rush(correctAnswers: 10), 2, "0 is outside 1…1000, so the default of 5 applies")
        Tuning.source = { [:] }
        XCTAssertEqual(CoinRewards.clear(newStars: 1, isFirstStageClear: false, isFirstBossClear: false), 10)
    }

    func testReviveRulesFollowTuningAndTheDailyFlag() {
        XCTAssertEqual(Tuning.reviveRules(), ReviveRules.defaults)
        Tuning.source = { ["revive.coinCost": .number(80), "revive.maxPerRun": .number(3), "revive.starCap": .number(2),
                           "revive.heartsRestored": .number(2), "plus.freeRevivesPerRun": .number(2)] }
        FeatureFlags.source = { ["reviveInDaily": true] }
        XCTAssertEqual(Tuning.reviveRules(), ReviveRules(coinCost: 80, heartsRestored: 2, maxPerRun: 3, starCap: 2,
                                                         plusFreeRevivesPerRun: 2, reviveInDaily: true))
    }
}

final class FlagGatingTests: XCTestCase {

    override func tearDown() {
        FeatureFlags.source = { LiveConfig.flags }
        super.tearDown()
    }

    func testTheMicrophoneFlagForcesTouchPlayButKeepsTheStoredChoice() {
        let suite = "FlagGating-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = ProgressStore(defaults: defaults)
        progress.inputMode = .pianika

        FeatureFlags.source = { [:] }
        XCTAssertEqual(progress.effectiveInputMode, .pianika, "default on")
        FeatureFlags.source = { ["micInput": false] }
        XCTAssertEqual(progress.effectiveInputMode, .touch)
        XCTAssertEqual(progress.inputMode, .pianika, "the choice is not erased")
        FeatureFlags.source = { ["micInput": true] }
        XCTAssertEqual(progress.effectiveInputMode, .pianika)
    }

    func testTheFlagsDefaultToTheBehaviourTheAppHadBefore() {
        FeatureFlags.source = { [:] }
        for key in [FlagKey.shop, .dailyChallenge, .micInput, .coinStore] { XCTAssertTrue(FeatureFlags.isOn(key), key.rawValue) }
    }
}

final class LocalizedTitlesTests: XCTestCase {

    func testASongShowsItsTitleInTheFirstAvailableLanguageAndKeepsTheCanonicalTitleAsTheKey() {
        let song = Song(id: "x", title: "Lagu Baru", notationImage: "", packId: "extra",
                        localizedTitles: LocalizedText(["en": "New Song", "id": "Lagu Baru", "ms": "Lagu Baharu"]),
                        keyIds: [5], isSolemn: false)
        XCTAssertEqual(song.title, "Lagu Baru")
        XCTAssertEqual(LocalizedText(["en": "New Song", "ms": "Lagu Baharu"]).resolved(preferred: ["ms-MY"]), "Lagu Baharu", "a third language needs no code")
        XCTAssertFalse(song.displayTitle.isEmpty)
    }

    func testASongWithoutLocalizedTitlesShowsItsCanonicalTitle() {
        let song = Song(id: "x", title: "Halo Halo Bandung", notationImage: "", keyIds: [5], isSolemn: false)
        XCTAssertEqual(song.displayTitle, "Halo Halo Bandung")
    }

    func testAFixtureWithoutEnglishStillShowsSomething() {
        XCTAssertEqual(LocalizedText(["ja": "さくら"]).resolved(preferred: ["fr"]), "さくら")
    }
}
