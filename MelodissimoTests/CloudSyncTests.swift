import XCTest
@testable import Melodissimo

final class CloudSyncTests: XCTestCase {

    private let titles: Set<String> = ["Indonesia Raya"]

    private func merge(_ local: [String: Any], _ remote: [String: Any]) -> CloudMerge.Result {
        CloudMerge.merge(local: local, remote: remote, songTitles: titles)
    }

    func testNumbersKeepTheLargerValueOnBothSides() {
        let result = merge(["song_bestScore_a": 500, "coins_earnedTotal": 90, "stat_fullCombos": 1],
                           ["song_bestScore_a": 800, "coins_earnedTotal": 40])
        XCTAssertEqual(result.local["song_bestScore_a"] as? Int, 800)
        XCTAssertNil(result.remote["song_bestScore_a"])
        XCTAssertNil(result.local["coins_earnedTotal"])
        XCTAssertEqual(result.remote["coins_earnedTotal"] as? Int, 90)
        XCTAssertEqual(result.remote["stat_fullCombos"] as? Int, 1, "a key only this device has is uploaded")
    }

    func testAccuracyDoublesKeepTheLarger() {
        let result = merge(["song_bestAccuracy_a": 91.5], ["song_bestAccuracy_a": 97.25])
        XCTAssertEqual(result.local["song_bestAccuracy_a"] as? Double, 97.25)
    }

    func testFlagsAreOrEd() {
        let result = merge(["achievement_x": true, "song_practiced_a": false, "Indonesia Raya": false],
                           ["achievement_x": false, "song_practiced_a": true, "Indonesia Raya": true])
        XCTAssertNil(result.local["achievement_x"])
        XCTAssertEqual(result.remote["achievement_x"] as? Bool, true)
        XCTAssertEqual(result.local["song_practiced_a"] as? Bool, true)
        XCTAssertEqual(result.local["Indonesia Raya"] as? Bool, true, "trophy flags are keyed by song title")
    }

    func testOwnedShopItemsAreUnioned() {
        let result = merge(["shop_owned": ["a", "b"]], ["shop_owned": ["b", "c"]])
        XCTAssertEqual(result.local["shop_owned"] as? [String], ["a", "b", "c"])
        XCTAssertEqual(result.remote["shop_owned"] as? [String], ["a", "b", "c"])
    }

    func testEquippedItemStaysLocalButFillsInWhenMissing() {
        let both = merge(["equip_keyboard": "gold"], ["equip_keyboard": "navy"])
        XCTAssertNil(both.local["equip_keyboard"])
        let onlyRemote = merge([:], ["equip_keyboard": "navy"])
        XCTAssertEqual(onlyRemote.local["equip_keyboard"] as? String, "navy")
    }

    func testTheTourCompletionDayKeepsTheEarliest() {
        let result = merge(["stat_tourCompletedAt": 2000.0], ["stat_tourCompletedAt": 1000.0])
        XCTAssertEqual(result.local["stat_tourCompletedAt"] as? Double, 1000)
    }

    func testStreakFollowsWhoeverPlayedLast() {
        let early = Date(timeIntervalSince1970: 1000), late = Date(timeIntervalSince1970: 90_000)
        let result = merge(["currentStreak": 2, "lastPlayedDate": early, "longestStreak": 9],
                           ["currentStreak": 5, "lastPlayedDate": late, "longestStreak": 5])
        XCTAssertEqual(result.local["currentStreak"] as? Int, 5)
        XCTAssertEqual(result.local["lastPlayedDate"] as? Date, late)
        XCTAssertNil(result.local["longestStreak"], "longest streak keeps the larger, which is local")
        XCTAssertEqual(result.remote["longestStreak"] as? Int, 9)
    }

    func testSettingsAndQuestionSetsNeverSync() {
        let result = merge(["settings_approachTime": 1.5, "Level3": [1, 2], "settings_inputMode": "pianika"], [:])
        XCTAssertTrue(result.local.isEmpty)
        XCTAssertTrue(result.remote.isEmpty)
        XCTAssertFalse(CloudMerge.isSynced("settings_audioOffsetMs", songTitles: titles))
        XCTAssertFalse(CloudMerge.isSynced("Level12", songTitles: titles))
    }

    func testMergingIsOrderIndependentAndSettles() {
        let a: [String: Any] = ["song_stars_x": 2, "shop_owned": ["p"], "achievement_k": true, "coins_spentTotal": 10]
        let b: [String: Any] = ["song_stars_x": 3, "shop_owned": ["q"], "coins_earnedTotal": 70, "coins_spentTotal": 30]
        let ab = merge(a, b), ba = merge(b, a)
        var aFinal = a, bFinal = b
        for (k, v) in ab.local { aFinal[k] = v }
        for (k, v) in ab.remote { bFinal[k] = v }
        XCTAssertEqual(aFinal["song_stars_x"] as? Int, 3)
        XCTAssertEqual(bFinal["achievement_k"] as? Bool, true)
        XCTAssertEqual(aFinal["shop_owned"] as? [String], ["p", "q"])
        XCTAssertEqual(bFinal["coins_spentTotal"] as? Int, 30)
        XCTAssertTrue(merge(aFinal, bFinal).local.isEmpty && merge(aFinal, bFinal).remote.isEmpty, "a second pass changes nothing")
        XCTAssertEqual(ba.local["shop_owned"] as? [String], ["p", "q"])
    }

    // MARK: Service

    private final class FakeStore: SyncStore {
        var values: [String: Any]
        init(_ values: [String: Any] = [:]) { self.values = values }
        func snapshot() -> [String: Any] { values }
        func set(_ value: Any, forKey key: String) { values[key] = value }
        func remove(forKey key: String) { values.removeValue(forKey: key) }
    }

    func testSyncPushesAndPullsAndLeavesSettingsAlone() {
        let local = FakeStore(["song_stars_a": 1, "settings_audioOffsetMs": 40, "bestCombo": 12])
        let cloud = FakeStore(["song_stars_a": 3, "stat_songsPerformed": 4])
        let sync = CloudSync(local: local, cloud: cloud, songTitles: titles)
        let changed = Set(sync.sync())
        XCTAssertEqual(changed, ["song_stars_a", "stat_songsPerformed"])
        XCTAssertEqual(local.values["song_stars_a"] as? Int, 3)
        XCTAssertEqual(local.values["stat_songsPerformed"] as? Int, 4)
        XCTAssertEqual(cloud.values["bestCombo"] as? Int, 12)
        XCTAssertNil(cloud.values["settings_audioOffsetMs"])
        XCTAssertTrue(sync.sync().isEmpty, "already in agreement")
    }

    func testForgetProgressClearsOnlySyncedKeysFromTheCloud() {
        let cloud = FakeStore(["song_stars_a": 3, "something_else": 1])
        CloudSync(local: FakeStore(), cloud: cloud, songTitles: titles).forgetProgress()
        XCTAssertNil(cloud.values["song_stars_a"])
        XCTAssertNotNil(cloud.values["something_else"])
    }

    func testCloudStoreIsNotCreatedUntilNeeded() {
        var made = 0
        let sync = CloudSync(local: FakeStore(), cloudFactory: { made += 1; return FakeStore() },
                             isEnabled: { false }, songTitles: titles)
        sync.start()
        XCTAssertTrue(sync.sync().isEmpty)
        sync.forgetProgress()
        sync.syncSoon()
        XCTAssertEqual(made, 0, "disabled sync must never touch the cloud store")
    }

    func testCloudStoreIsCreatedOnceWhenEnabled() {
        var made = 0
        let sync = CloudSync(local: FakeStore(["song_stars_a": 1]), cloudFactory: { made += 1; return FakeStore() },
                             isEnabled: { true }, songTitles: titles)
        _ = sync.sync()
        _ = sync.sync()
        XCTAssertEqual(made, 1)
    }
}
