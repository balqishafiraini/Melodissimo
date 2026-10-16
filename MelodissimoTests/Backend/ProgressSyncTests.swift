import XCTest
@testable import Melodissimo

private final class DictStore: SyncStore {
    var values: [String: Any]
    init(_ values: [String: Any] = [:]) { self.values = values }
    func snapshot() -> [String: Any] { values }
    func set(_ value: Any, forKey key: String) { values[key] = value }
    func remove(forKey key: String) { values.removeValue(forKey: key) }
}

final class ProgressMergeVectorTests: XCTestCase {

    private struct Vectors: Decodable {
        struct Value: Decodable { let rule: String; let local: JSONValue?; let remote: JSONValue?; let expected: JSONValue? }
        struct Streak: Decodable { let local: JSONValue?; let remote: JSONValue?; let expected: JSONValue? }
        let value: [Value]
        let streak: [Streak]
    }

    private func rule(_ name: String) throws -> CloudMerge.Rule {
        switch name {
        case "max": return .max
        case "earliest": return .earliest
        case "or": return .or
        case "union": return .union
        case "keepLocal": return .keepLocal
        default: throw XCTSkip("unknown rule \(name)")
        }
    }

    /// A JSON vector value as the kind of value `UserDefaults` holds.
    private func native(_ value: JSONValue?) -> Any? {
        switch value {
        case .none, .null?: return nil
        case .bool(let b)?: return b
        case .number(let n)?: return n == n.rounded() ? NSNumber(value: Int(n)) : NSNumber(value: n)
        case .string(let s)?: return s
        case .array(let items)?: return items.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        case .object?: return nil
        }
    }

    func testTheSharedValueVectorsMatchTheServer() throws {
        let vectors = try JSONDecoder().decode(Vectors.self, from: fixtureData("progress-merge-vectors"))
        XCTAssertGreaterThanOrEqual(vectors.value.count, 25)
        for v in vectors.value {
            let merged = CloudMerge.mergeValue(try rule(v.rule), native(v.local), native(v.remote))
            let expected = native(v.expected)
            if let expected = expected as? [String] {
                XCTAssertEqual(merged as? [String], expected, "\(v.rule) \(String(describing: v.local)) \(String(describing: v.remote))")
            } else if let expected = expected as? NSNumber {
                XCTAssertEqual((merged as? NSNumber)?.doubleValue, expected.doubleValue, v.rule)
                XCTAssertEqual(merged is Bool, expected is Bool && merged is Bool, v.rule)
            } else if let expected = expected as? String {
                XCTAssertEqual(merged as? String, expected, v.rule)
            } else {
                XCTAssertNil(merged, "\(v.rule) \(String(describing: v.local)) \(String(describing: v.remote))")
            }
        }
    }

    private func streakDict(_ value: JSONValue?) -> [String: Any] {
        guard case .object(let fields)? = value, case .number(let n)? = fields["currentStreak"], case .string(let text)? = fields["lastPlayedDate"],
              let date = ISO8601DateFormatter().date(from: text) else { return [:] }
        return ["currentStreak": Int(n), "lastPlayedDate": date]
    }

    func testTheSharedStreakVectorsMatchTheServer() throws {
        let vectors = try JSONDecoder().decode(Vectors.self, from: fixtureData("progress-merge-vectors"))
        for v in vectors.streak {
            let winner = CloudMerge.mergeStreak(local: streakDict(v.local), remote: streakDict(v.remote))
            let expected = streakDict(v.expected)
            if expected.isEmpty {
                XCTAssertNil(winner)
            } else {
                XCTAssertEqual(winner?["currentStreak"] as? Int, expected["currentStreak"] as? Int)
                XCTAssertEqual(winner?["lastPlayedDate"] as? Date, expected["lastPlayedDate"] as? Date)
            }
        }
    }
}

final class ProgressDocumentTests: XCTestCase {

    private let titles: Set<String> = ["Halo Halo Bandung"]

    func testASnapshotBecomesATaggedDocumentAndBack() {
        let date = ISO8601DateFormatter().date(from: "2026-10-15T00:00:00Z")!
        let snapshot: [String: Any] = [
            "coins_earnedTotal": 120, "song_stars_halo-halo-bandung": 3, "achievement_first_star": true, "Halo Halo Bandung": true,
            "shop_owned": ["b", "a"], "equip_keyboard": "keyboard_gold", "currentStreak": 4, "lastPlayedDate": date,
            "settings_approachTime": 2.0, "Level3": [1, 2], "inv_gained_boost_heart": 6,
        ]
        let doc = ProgressDocument.entries(from: snapshot, songTitles: titles)
        XCTAssertEqual(doc["coins_earnedTotal"], ProgressEntry(r: "max", v: .number(120)))
        XCTAssertEqual(doc["achievement_first_star"], ProgressEntry(r: "or", v: .bool(true)))
        XCTAssertEqual(doc["Halo Halo Bandung"], ProgressEntry(r: "or", v: .bool(true)), "a trophy flag syncs by its title")
        XCTAssertEqual(doc["shop_owned"], ProgressEntry(r: "union", v: .array([.string("a"), .string("b")])))
        XCTAssertEqual(doc["equip_keyboard"], ProgressEntry(r: "keepLocal", v: .string("keyboard_gold")))
        XCTAssertEqual(doc["inv_gained_boost_heart"], ProgressEntry(r: "max", v: .number(6)))
        XCTAssertNil(doc["settings_approachTime"], "settings never sync")
        XCTAssertNil(doc["Level3"], "question sets never sync")
        XCTAssertNil(doc["currentStreak"], "the streak pair travels as one entry")
        XCTAssertEqual(doc[ProgressDocument.streakKey]?.r, "streak")

        let values = ProgressDocument.values(from: doc)
        XCTAssertEqual(values["coins_earnedTotal"] as? Int, 120)
        XCTAssertEqual(values["achievement_first_star"] as? Bool, true)
        XCTAssertEqual(values["shop_owned"] as? [String], ["a", "b"])
        XCTAssertEqual(values["currentStreak"] as? Int, 4)
        XCTAssertEqual(values["lastPlayedDate"] as? Date, date)
    }

    func testBoolsAndNumbersAreNotMixedUp() {
        let doc = ProgressDocument.entries(from: ["isPreplayDone": true, "coins_earnedTotal": 1, "stat_x": 0], songTitles: [])
        XCTAssertEqual(doc["isPreplayDone"]?.v, .bool(true))
        XCTAssertEqual(doc["coins_earnedTotal"]?.v, .number(1))
        XCTAssertEqual(doc["stat_x"]?.v, .number(0))
    }
}

final class ProgressSyncServiceTests: XCTestCase {

    private var requests: [(method: String, ifMatch: String?, auth: String?)] = []
    private var serverData: [String: ProgressEntry] = [:]
    private var serverRevision = 0
    private var conflictOnNextPut = false

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        requests = []
        serverData = [:]
        serverRevision = 0
        conflictOnNextPut = false
        StubURLProtocol.handler = { [unowned self] request in
            let body = request.bodyStreamData() ?? request.httpBody
            requests.append((request.httpMethod ?? "", request.value(forHTTPHeaderField: "If-Match"), request.value(forHTTPHeaderField: "Authorization")))
            func json(_ status: Int, _ error: String? = nil) throws -> (Int, Data) {
                var object: [String: Any] = ["revision": serverRevision, "data": try dataObject(serverData)]
                if let error { object["error"] = ["code": error] }
                return (status, try JSONSerialization.data(withJSONObject: object))
            }
            if request.httpMethod == "GET" { return try json(200) }
            if conflictOnNextPut {
                conflictOnNextPut = false
                serverData["from_other_device"] = ProgressEntry(r: "max", v: .number(77))
                serverRevision += 1
                return try json(409, "revision_mismatch")
            }
            let sent = try JSONDecoder().decode([String: [String: ProgressEntry]].self, from: try XCTUnwrap(body))["data"] ?? [:]
            for (key, entry) in sent {
                if let existing = serverData[key], case .number(let a) = existing.v, case .number(let b) = entry.v { serverData[key] = ProgressEntry(r: "max", v: .number(max(a, b))) }
                else { serverData[key] = entry }
            }
            serverRevision += 1
            return try json(200)
        }
    }

    override func tearDown() {
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func dataObject(_ data: [String: ProgressEntry]) throws -> [String: Any] {
        try data.mapValues { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) }
    }

    private func service(_ local: DictStore, enabled: Bool = true) -> ProgressSyncService {
        ProgressSyncService(local: local,
                            makeClient: { APIClient(baseURL: URL(string: "https://api.test"), session: StubURLProtocol.session(),
                                                    headers: { ClientHeaders(version: "1", build: 1, installId: "i", contentVersion: 0, schemaVersion: 1, languages: [], storefront: "") },
                                                    authorization: { "player-token" }) },
                            isEnabled: { enabled }, songTitles: { [] })
    }

    func testTheServersProgressComesDownAndThisDevicesGoesUp() async {
        serverData = ["coins_earnedTotal": ProgressEntry(r: "max", v: .number(200)), "shop_owned": ProgressEntry(r: "union", v: .array([.string("keyboard_batik")]))]
        serverRevision = 3
        let local = DictStore(["coins_earnedTotal": 50, "shop_owned": ["notes_neon"], "stat_fullCombos": 2])
        let ok = await service(local).sync()
        XCTAssertTrue(ok)
        XCTAssertEqual(local.values["coins_earnedTotal"] as? Int, 200)
        XCTAssertEqual(local.values["shop_owned"] as? [String], ["keyboard_batik", "notes_neon"])
        XCTAssertEqual(serverData["stat_fullCombos"]?.v, .number(2))
        XCTAssertEqual(requests.map(\.method), ["GET", "PUT"])
        XCTAssertEqual(requests[1].ifMatch, "3")
        XCTAssertEqual(requests[1].auth, "Bearer player-token")
    }

    func testAConflictMergesTheOtherDevicesCopyAndRetries() async {
        conflictOnNextPut = true
        let local = DictStore(["coins_earnedTotal": 50])
        let ok = await service(local).sync()
        XCTAssertTrue(ok)
        XCTAssertEqual(local.values["from_other_device"] as? Int, nil, "unknown keys are ignored by this build")
        XCTAssertEqual(requests.map(\.method), ["GET", "PUT", "PUT"])
        XCTAssertEqual(requests[2].ifMatch, "1", "the retry carries the revision from the conflict")
    }

    func testNothingHappensWithoutAnAccount() async {
        let ok = await service(DictStore(["coins_earnedTotal": 5]), enabled: false).sync()
        XCTAssertFalse(ok)
        XCTAssertTrue(requests.isEmpty)
    }

    func testAnOfflineSyncChangesNothing() async {
        StubURLProtocol.handler = nil
        let local = DictStore(["coins_earnedTotal": 5])
        let ok = await service(local).sync()
        XCTAssertFalse(ok)
        XCTAssertEqual(local.values["coins_earnedTotal"] as? Int, 5)
    }

    func testTwoDevicesConvergeThroughTheServer() async {
        let a = DictStore(["coins_earnedTotal": 50, "shop_owned": ["a"]])
        let b = DictStore(["coins_earnedTotal": 90, "shop_owned": ["b"]])
        _ = await service(a).sync()
        _ = await service(b).sync()
        _ = await service(a).sync()
        XCTAssertEqual(a.values["coins_earnedTotal"] as? Int, 90)
        XCTAssertEqual(b.values["coins_earnedTotal"] as? Int, 90)
        XCTAssertEqual(a.values["shop_owned"] as? [String], ["a", "b"])
        XCTAssertEqual(b.values["shop_owned"] as? [String], ["a", "b"])
    }
}

/// A `PlayerAccount` wired to the stubbed network, exposing its client so tests can call the API as the app would.
@MainActor
final class PlayerAccountUnderTest {
    let account: PlayerAccount
    init(keychain: KeychainStore, defaults: UserDefaults, enabled: Bool) {
        account = PlayerAccount(keychain: keychain, defaults: defaults,
                                makeClient: { account in
                                    APIClient(baseURL: URL(string: "https://api.test"), session: StubURLProtocol.session(),
                                              headers: { ClientHeaders(version: "1", build: 1, installId: "i", contentVersion: 0, schemaVersion: 1, languages: [], storefront: "") },
                                              authorization: { account.token },
                                              onResponse: { response in if let fresh = response.value(forHTTPHeaderField: "X-Refreshed-Token") { account.store(token: fresh) } })
                                },
                                isEnabled: { enabled })
    }
    var state: AccountState { account.state }
    var lastError: String? { account.lastError }
    func ensurePlayer() async { await account.ensurePlayer() }
    func linkApple(identityToken: String) async -> Bool { await account.linkApple(identityToken: identityToken) }
    func signOut() { account.signOut() }
    func client() -> APIClient {
        APIClient(baseURL: URL(string: "https://api.test"), session: StubURLProtocol.session(),
                  headers: { ClientHeaders(version: "1", build: 1, installId: "i", contentVersion: 0, schemaVersion: 1, languages: [], storefront: "") },
                  authorization: { [account] in account.token },
                  onResponse: { [account] response in if let fresh = response.value(forHTTPHeaderField: "X-Refreshed-Token") { account.store(token: fresh) } })
    }
}

@MainActor
final class PlayerAccountTests: XCTestCase {

    private var keychain: KeychainStore!
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        keychain = KeychainStore(service: "melodissimo.tests.\(UUID().uuidString)")
        suite = "PlayerAccountTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        keychain.delete("playerToken")
        defaults.removePersistentDomain(forName: suite)
        StubURLProtocol.reset()
        super.tearDown()
    }

    private func account(enabled: Bool = true) -> PlayerAccountUnderTest {
        PlayerAccountUnderTest(keychain: keychain, defaults: defaults, enabled: enabled)
    }

    func testTheKeychainStoresReadsUpdatesAndDeletes() {
        XCTAssertNil(keychain.read("k"))
        XCTAssertTrue(keychain.write("one", for: "k"))
        XCTAssertEqual(keychain.read("k"), "one")
        XCTAssertTrue(keychain.write("two", for: "k"))
        XCTAssertEqual(keychain.read("k"), "two")
        keychain.delete("k")
        XCTAssertNil(keychain.read("k"))
    }

    func testAnAnonymousPlayerIsCreatedOnceAndItsTokenIsKept() async {
        StubURLProtocol.handler = { _ in (201, Data(#"{"playerId": "p1", "token": "tok-1"}"#.utf8)) }
        let a = account()
        XCTAssertEqual(a.state, .signedOut)
        await a.ensurePlayer()
        XCTAssertEqual(a.state, .anonymous)
        XCTAssertEqual(keychain.read("playerToken"), "tok-1")
        await a.ensurePlayer()
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "no second player for the same install")
        XCTAssertEqual(account().state, .anonymous, "the state survives a relaunch")
    }

    func testNothingIsCreatedWhileAccountsAreOff() async {
        StubURLProtocol.handler = { _ in (201, Data(#"{"playerId": "p1", "token": "tok-1"}"#.utf8)) }
        let a = account(enabled: false)
        await a.ensurePlayer()
        XCTAssertEqual(a.state, .signedOut)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testAnAlreadyRegisteredInstallLeavesTheAppSignedOut() async {
        StubURLProtocol.handler = { _ in (409, Data(#"{"error": {"code": "already_registered"}}"#.utf8)) }
        let a = account()
        await a.ensurePlayer()
        XCTAssertEqual(a.state, .signedOut)
        XCTAssertNotNil(a.lastError)
    }

    func testLinkingAppleKeepsTheSurvivingPlayersToken() async {
        StubURLProtocol.handler = { request in
            if request.url?.path == "/v1/players" { return (201, Data(#"{"playerId": "p-anon", "token": "tok-anon"}"#.utf8)) }
            return (200, Data(#"{"playerId": "p-main", "token": "tok-main", "merged": true}"#.utf8))
        }
        let a = account()
        let ok = await a.linkApple(identityToken: "apple.jwt")
        XCTAssertTrue(ok)
        XCTAssertEqual(a.state, .linked)
        XCTAssertEqual(keychain.read("playerToken"), "tok-main")
        let link = StubURLProtocol.requests.last
        XCTAssertEqual(link?.url?.path, "/v1/players/link")
        XCTAssertEqual(link?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-anon")
    }

    func testABadAppleTokenLeavesThePlayerAnonymous() async {
        StubURLProtocol.handler = { request in
            request.url?.path == "/v1/players" ? (201, Data(#"{"playerId": "p", "token": "t"}"#.utf8)) : (401, Data(#"{"error": {"code": "bad_identity"}}"#.utf8))
        }
        let a = account()
        let ok = await a.linkApple(identityToken: "bad")
        XCTAssertFalse(ok)
        XCTAssertEqual(a.state, .anonymous)
    }

    func testARefreshedTokenReplacesTheOldOne() async throws {
        keychain.write("old", for: "playerToken")
        StubURLProtocol.handler = { _ in (200, Data(#"{"playerId": "p", "links": []}"#.utf8)) }
        StubURLProtocol.responseHeaders = ["X-Refreshed-Token": "new"]
        let a = account()
        struct Me: Decodable { let playerId: String }
        let _: Me = try await a.client().get("v1/players/me")
        XCTAssertEqual(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer old")
        XCTAssertEqual(keychain.read("playerToken"), "new")
    }

    func testSigningOutForgetsTheSession() async {
        keychain.write("tok", for: "playerToken")
        defaults.set(true, forKey: "backend_playerLinked")
        let a = account()
        XCTAssertEqual(a.state, .linked)
        a.signOut()
        XCTAssertEqual(a.state, .signedOut)
        XCTAssertNil(keychain.read("playerToken"))
    }
}

private extension URLRequest {
    func bodyStreamData() -> Data? {
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
