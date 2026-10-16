import CryptoKit
import XCTest
@testable import Melodissimo

private struct FakeBaseline: ContentBaseline {
    var manifestData: Data?
    var signature: String?
    var files: [String: URL] = [:]
    func assetURL(sha256: String, fileExtension: String) -> URL? { files["\(sha256).\(fileExtension)"] }
}

final class ManifestVerifierTests: XCTestCase {

    private struct Vector: Decodable { let publicKey: String; let messageBase64: String; let signatureBase64: String }

    func testTheSharedSignatureVectorVerifiesAndATamperedMessageDoesNot() throws {
        let v = try JSONDecoder().decode(Vector.self, from: fixtureData("signature-vector"))
        let verifier = ManifestVerifier(trustedKeys: [v.publicKey])
        var message = try XCTUnwrap(Data(base64Encoded: v.messageBase64))
        XCTAssertTrue(verifier.verifySignature(of: message, signature: v.signatureBase64))
        message[0] ^= 1
        XCTAssertFalse(verifier.verifySignature(of: message, signature: v.signatureBase64))
    }

    func testAnyTrustedKeyMaySignAndAnUntrustedOneMayNot() {
        let a = Curve25519.Signing.PrivateKey()
        let b = Curve25519.Signing.PrivateKey()
        let data = Data("manifest".utf8)
        let sig = try! a.signature(for: data).base64EncodedString()
        XCTAssertTrue(ManifestVerifier(trustedKeys: [b.publicKey.rawRepresentation.base64EncodedString(), a.publicKey.rawRepresentation.base64EncodedString()])
            .verifySignature(of: data, signature: sig))
        XCTAssertFalse(ManifestVerifier(trustedKeys: [b.publicKey.rawRepresentation.base64EncodedString()]).verifySignature(of: data, signature: sig))
        XCTAssertFalse(ManifestVerifier(trustedKeys: []).verifySignature(of: data, signature: sig))
        XCTAssertFalse(ManifestVerifier(trustedKeys: ["not base64!"]).verifySignature(of: data, signature: sig))
    }

    func testMalformedSignaturesAreRejected() {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = ManifestVerifier(trustedKeys: [key.publicKey.rawRepresentation.base64EncodedString()])
        for bad in ["", "AAAA", "%%%", Data(count: 63).base64EncodedString()] {
            XCTAssertFalse(verifier.verifySignature(of: Data("x".utf8), signature: bad), bad)
        }
    }

    func testFileHashesAreStreamedAndMatchTheInMemoryHash() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hash-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = Data((0..<(3 * (1 << 20) + 17)).map { UInt8($0 % 251) })
        try data.write(to: url)
        XCTAssertEqual(ManifestVerifier.sha256Hex(ofFileAt: url), ManifestVerifier.sha256Hex(of: data))
        XCTAssertTrue(ManifestVerifier.fileMatches(url, sha256: ManifestVerifier.sha256Hex(of: data).uppercased()))
        XCTAssertFalse(ManifestVerifier.fileMatches(url, sha256: String(repeating: "0", count: 64)))
        XCTAssertNil(ManifestVerifier.sha256Hex(ofFileAt: url.appendingPathExtension("missing")))
        XCTAssertEqual(ManifestVerifier.sha256Hex(of: Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

final class ManifestDecodingTests: XCTestCase {

    func testTheExampleManifestDecodes() throws {
        let m = try ContentManifest.decode(fixtureData("manifest"))
        XCTAssertEqual(m.contentVersion, 12)
        XCTAssertEqual(m.minAppBuildIos, 57)
        XCTAssertEqual(m.assets["bgm.halo-halo-bandung"]?.fileExtension, "m4a")
        XCTAssertEqual(m.assets["bgm.halo-halo-bandung"]?.prefetch, false)
        XCTAssertEqual(m.songs.first?.canonicalTitle, "Halo Halo Bandung")
        XCTAssertEqual(m.songs.first?.chart, "chart.halo-halo-bandung")
        XCTAssertEqual(m.packs.map(\.id), ["core", "daerah-sumatra"])
        XCTAssertEqual(m.packs[1].access.productIds.count, 3)
        XCTAssertEqual(m.packs[1].markets?.featuredIn, ["IDN"])
        XCTAssertEqual(m.shopItems.map(\.id), ["keyboard_batik"])
        XCTAssertEqual(m.products.count, 6)
    }

    func testUnknownFieldsAreIgnoredAndBrokenEntriesSkipped() throws {
        let json = """
        {"schemaVersion": 1, "contentVersion": 3, "future": {"x": 1},
         "songs": [
           {"id": "a", "title": {"en": "A", "canonical": "A"}, "order": 1, "packId": "core", "newField": true},
           {"id": "b", "title": {"en": "B"}, "order": 2, "packId": "core", "status": "archived"},
           {"title": {"en": "no id"}, "order": 3, "packId": "core"}],
         "shop": {"items": [{"id": "keyboard_x", "category": "keyboard", "name": {"en": "X"}, "price": {"coins": 5}},
                            {"id": "hat_y", "category": "hat", "name": {"en": "Y"}, "price": {"coins": 5}}]}}
        """
        let m = try ContentManifest.decode(Data(json.utf8))
        XCTAssertEqual(m.songs.map(\.id), ["a"])
        XCTAssertEqual(m.shopItems.map(\.id), ["keyboard_x"])
        XCTAssertTrue(m.packs.isEmpty)
        XCTAssertTrue(m.assets.isEmpty)
    }
}

final class ContentStoreTests: XCTestCase {

    private var dir: URL!
    private let key = Curve25519.Signing.PrivateKey()
    private var verifier: ManifestVerifier { ManifestVerifier(trustedKeys: [key.publicKey.rawRepresentation.base64EncodedString()]) }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ContentStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func manifestJSON(version: Int, songs: [(String, Int, String)] = [("halo", 10, "live")], assets: String = "{}") -> Data {
        let list = songs.map { #"{"id": "\#($0.0)", "title": {"canonical": "\#($0.0)", "en": "\#($0.0)"}, "order": \#($0.1), "packId": "core", "status": "\#($0.2)"}"# }
        return Data(#"{"schemaVersion": 1, "contentVersion": \#(version), "songs": [\#(list.joined(separator: ","))], "assets": \#(assets), "packs": [{"id": "core", "title": {"en": "Core"}, "access": {"type": "free"}}]}"#.utf8)
    }

    private func sign(_ data: Data) -> String { try! key.signature(for: data).base64EncodedString() }

    private func store(baseline: FakeBaseline = FakeBaseline(), build: Int = 57) -> ContentStore {
        ContentStore(root: dir.appendingPathComponent("Content"), baseline: baseline, verifier: verifier, build: { build })
    }

    private func writeDownloaded(_ store: ContentStore, version: Int, data: Data, signature: String? = nil, activate: Bool = true) throws {
        try FileManager.default.createDirectory(at: store.manifestsDirectory, withIntermediateDirectories: true)
        let file = store.manifestsDirectory.appendingPathComponent("\(version).json")
        try data.write(to: file)
        try (signature ?? sign(data)).write(to: file.appendingPathExtension("sig"), atomically: true, encoding: .utf8)
        if activate {
            try FileManager.default.createDirectory(at: store.manifestsDirectory.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("{\"version\": \(version)}".utf8).write(to: store.manifestsDirectory.deletingLastPathComponent().appendingPathComponent("active.json"))
        }
    }

    func testBaselineOnly() throws {
        let data = manifestJSON(version: 0, songs: [("b", 20, "live"), ("a", 10, "live")])
        let s = store(baseline: FakeBaseline(manifestData: data, signature: sign(data)))
        s.loadActive()
        XCTAssertEqual(s.manifestVersion, 0)
        XCTAssertEqual(s.songs.map(\.id), ["a", "b"], "ordered by `order`")
        XCTAssertEqual(s.packs.map(\.id), ["core"])
    }

    func testNothingAtAllGivesAnEmptyStoreSoLegacyPathsStillWork() {
        let s = store()
        s.loadActive()
        XCTAssertNil(s.manifestVersion)
        XCTAssertTrue(s.songs.isEmpty)
        XCTAssertNil(s.url(forAsset: "chart.x"))
    }

    func testABaselineWithABadSignatureIsIgnored() {
        let data = manifestJSON(version: 0)
        let s = store(baseline: FakeBaseline(manifestData: data, signature: sign(Data("other".utf8))))
        s.loadActive()
        XCTAssertNil(s.manifestVersion)
    }

    func testADownloadedPackBeatsTheBaseline() throws {
        let base = manifestJSON(version: 0, songs: [("old", 10, "live")])
        let s = store(baseline: FakeBaseline(manifestData: base, signature: sign(base)))
        try writeDownloaded(s, version: 5, data: manifestJSON(version: 5, songs: [("new", 10, "live"), ("newer", 20, "live")]))
        s.loadActive()
        XCTAssertEqual(s.manifestVersion, 5)
        XCTAssertEqual(s.songs.map(\.id), ["new", "newer"])
    }

    func testATamperedDownloadedManifestIsRejectedAndTheBaselineStays() throws {
        let base = manifestJSON(version: 0, songs: [("old", 10, "live")])
        let s = store(baseline: FakeBaseline(manifestData: base, signature: sign(base)))
        let signed = manifestJSON(version: 5, songs: [("new", 10, "live")])
        let signature = sign(signed)
        try writeDownloaded(s, version: 5, data: manifestJSON(version: 5, songs: [("evil", 10, "live")]), signature: signature)
        s.loadActive()
        XCTAssertEqual(s.manifestVersion, 0)
        XCTAssertEqual(s.songs.map(\.id), ["old"])
    }

    func testAManifestSignedByAnUntrustedKeyIsRejected() throws {
        let stranger = Curve25519.Signing.PrivateKey()
        let s = store()
        let data = manifestJSON(version: 5)
        try writeDownloaded(s, version: 5, data: data, signature: try stranger.signature(for: data).base64EncodedString())
        s.loadActive()
        XCTAssertNil(s.manifestVersion)
    }

    func testItemsBuiltForANewerAppAndHiddenOnesAreDropped() throws {
        let data = Data(#"""
        {"schemaVersion": 1, "contentVersion": 1, "songs": [
          {"id": "a", "title": {"en": "A"}, "order": 1, "packId": "core"},
          {"id": "b", "title": {"en": "B"}, "order": 2, "packId": "core", "minAppBuild": 60},
          {"id": "c", "title": {"en": "C"}, "order": 3, "packId": "core", "status": "hidden"},
          {"id": "d", "title": {"en": "D"}, "order": 4, "packId": "core", "status": "comingSoon"},
          {"id": "e", "title": {"en": "E"}, "order": 5, "packId": "core", "status": "somethingNew"}]}
        """#.utf8)
        let s = store(baseline: FakeBaseline(manifestData: data, signature: sign(data)), build: 57)
        s.loadActive()
        XCTAssertEqual(s.songs.map(\.id), ["a", "d"])
        XCTAssertEqual(store(baseline: FakeBaseline(manifestData: data, signature: sign(data)), build: 60).songs.map(\.id), [])
        let newer = store(baseline: FakeBaseline(manifestData: data, signature: sign(data)), build: 60)
        newer.loadActive()
        XCTAssertEqual(newer.songs.map(\.id), ["a", "b", "d"])
    }

    func testAssetsResolveFromTheDownloadFirstThenTheBaseline() throws {
        let sha1 = String(repeating: "1", count: 64), sha2 = String(repeating: "2", count: 64), sha3 = String(repeating: "3", count: 64)
        let baseFile = dir.appendingPathComponent("base-\(sha1).m4a")
        try Data("old audio".utf8).write(to: baseFile)
        let baseAssets = #"{"bgm.halo": {"path": "assets/\#(sha1).m4a", "sha256": "\#(sha1)", "bytes": 9, "kind": "audio"}}"#
        let base = manifestJSON(version: 0, assets: baseAssets)
        let s = store(baseline: FakeBaseline(manifestData: base, signature: sign(base), files: ["\(sha1).m4a": baseFile]))
        let newAssets = #"{"bgm.halo": {"path": "assets/\#(sha2).m4a", "sha256": "\#(sha2)", "bytes": 9, "kind": "audio"}, "chart.new": {"path": "assets/\#(sha3).json", "sha256": "\#(sha3)", "bytes": 2, "kind": "chart"}}"#
        try writeDownloaded(s, version: 5, data: manifestJSON(version: 5, assets: newAssets))
        s.loadActive()

        // The new audio isn't downloaded yet: the baseline's copy of the same key is used.
        XCTAssertEqual(s.url(forAsset: "bgm.halo"), baseFile)
        XCTAssertNil(s.url(forAsset: "chart.new"))

        try FileManager.default.createDirectory(at: s.assetsDirectory, withIntermediateDirectories: true)
        let downloaded = s.assetsDirectory.appendingPathComponent("\(sha2).m4a")
        try Data("new audio".utf8).write(to: downloaded)
        XCTAssertEqual(s.url(forAsset: "bgm.halo"), downloaded, "downloaded beats baseline")
        XCTAssertNil(s.url(forAsset: "chart.unknown"))
    }

    func testActivatingAVersionVerifiesItAndPersistsThePointer() throws {
        let s = store()
        let data = manifestJSON(version: 7)
        try writeDownloaded(s, version: 7, data: data, activate: false)
        XCTAssertTrue(s.activate(version: 7))
        XCTAssertEqual(s.manifestVersion, 7)
        let fresh = store()
        fresh.loadActive()
        XCTAssertEqual(fresh.manifestVersion, 7, "the pointer survives a relaunch")
        XCTAssertFalse(s.activate(version: 99), "no such download")
    }

    func testTheBundledBaselineOfTheAppIsSignedByATrustedKey() throws {
        let s = ContentStore(root: dir.appendingPathComponent("Content"))
        s.loadActive()
        XCTAssertEqual(s.manifestVersion, 0)
        XCTAssertEqual(s.songs.count, 16)
        XCTAssertEqual(s.songs.first?.canonicalTitle, "Indonesia Raya")
        for song in s.songs {
            let chart = try XCTUnwrap(song.chart)
            XCTAssertNotNil(s.url(forAsset: chart), "chart for \(song.id)")
            XCTAssertNotNil(song.backing.flatMap { s.url(forAsset: $0) }, "backing for \(song.id)")
        }
    }
}
