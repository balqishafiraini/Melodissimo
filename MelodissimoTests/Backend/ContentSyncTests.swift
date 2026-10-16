import CryptoKit
import XCTest
@testable import Melodissimo

final class ContentSyncTests: XCTestCase {

    private var dir: URL!
    private let key = Curve25519.Signing.PrivateKey()
    private var verifier: ManifestVerifier { ManifestVerifier(trustedKeys: [key.publicKey.rawRepresentation.base64EncodedString()]) }
    private let cdn = "https://cdn.test"

    /// The files a fake CDN serves, by path.
    private var served: [String: Data] = [:]
    private var requested: [String] = []
    private var failuresLeft: [String: Int] = [:]

    override func setUpWithError() throws {
        StubURLProtocol.reset()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ContentSyncTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        served = [:]
        requested = []
        failuresLeft = [:]
        StubURLProtocol.handler = { [unowned self] request in
            let path = request.url!.path
            requested.append(path)
            if let left = failuresLeft[path], left > 0 {
                failuresLeft[path] = left - 1
                return (503, Data())
            }
            guard let data = served[path] else { return (404, Data()) }
            return (200, data)
        }
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        StubURLProtocol.reset()
        super.tearDown()
    }

    private struct Release {
        var version: Int
        var manifest: Data
        var signature: String
        var info: Bootstrap.ContentInfo
    }

    /// Publishes a release on the fake CDN: a chart (prefetch), a sheet (prefetch) and audio (on demand).
    @discardableResult
    private func publish(version: Int, schema: Int = 1, minBuild: Int = 1, corruptAsset: Bool = false, badSignature: Bool = false,
                         wrongHash: Bool = false) -> Release {
        let chart = Data("chart-\(version)".utf8), sheet = Data("sheet-\(version)".utf8), audio = Data("audio-\(version)".utf8)
        let hashes = [chart, sheet, audio].map(ManifestVerifier.sha256Hex(of:))
        served["/assets/\(hashes[0]).json"] = corruptAsset ? Data("tampered".utf8) : chart
        served["/assets/\(hashes[1]).png"] = sheet
        served["/assets/\(hashes[2]).m4a"] = audio
        let json = """
        {"schemaVersion": \(schema), "contentVersion": \(version), "minAppBuild": {"ios": \(minBuild)},
         "assets": {
           "chart.halo": {"path": "assets/\(hashes[0]).json", "sha256": "\(hashes[0])", "bytes": \(chart.count), "kind": "chart", "prefetch": true},
           "sheet.halo": {"path": "assets/\(hashes[1]).png", "sha256": "\(hashes[1])", "bytes": \(sheet.count), "kind": "image", "prefetch": true},
           "bgm.halo": {"path": "assets/\(hashes[2]).m4a", "sha256": "\(hashes[2])", "bytes": \(audio.count), "kind": "audio", "prefetch": false}},
         "songs": [{"id": "halo", "title": {"canonical": "Halo", "en": "Halo"}, "order": 1, "packId": "core", "chart": "chart.halo", "backing": "bgm.halo", "sheet": "sheet.halo"}],
         "packs": [{"id": "core", "title": {"en": "Core"}, "access": {"type": "free"}}]}
        """
        let manifest = Data(json.utf8)
        let signature = badSignature ? try! key.signature(for: Data("other".utf8)).base64EncodedString() : try! key.signature(for: manifest).base64EncodedString()
        served["/manifests/\(version).json"] = manifest
        served["/manifests/\(version).json.sig"] = Data(signature.utf8)
        let info = Bootstrap.ContentInfo(version: version, schemaVersion: schema, manifestUrl: "\(cdn)/manifests/\(version).json",
                                         signatureUrl: "\(cdn)/manifests/\(version).json.sig",
                                         sha256: wrongHash ? String(repeating: "0", count: 64) : ManifestVerifier.sha256Hex(of: manifest))
        return Release(version: version, manifest: manifest, signature: signature, info: info)
    }

    private func makeStore() -> ContentStore {
        ContentStore(root: dir.appendingPathComponent("Content"), baseline: BundleBaselineStub(), verifier: verifier, build: { 57 })
    }

    private struct BundleBaselineStub: ContentBaseline {
        var manifestData: Data? { nil }
        var signature: String? { nil }
        func assetURL(sha256: String, fileExtension: String) -> URL? { nil }
    }

    private func sync(_ store: ContentStore, build: Int = 57, schema: Int = 1) -> ContentSync {
        let downloader = AssetDownloader(session: StubURLProtocol.session(), sleep: { _ in })
        return ContentSync(store: store, downloader: downloader, verifier: verifier, supportedSchema: schema, build: { build })
    }

    func testAReleaseIsStagedFirstAndActivatedOnlyWhenIdle() async throws {
        let store = makeStore()
        store.loadActive()
        let release = publish(version: 3)
        let ok = await sync(store).sync(to: release.info)
        XCTAssertTrue(ok)
        XCTAssertEqual(store.stagedVersion, 3)
        XCTAssertNil(store.manifestVersion, "staged, not active yet")
        XCTAssertFalse(store.activateStagedIfIdle(isIdle: false), "a song is playing")
        XCTAssertNil(store.manifestVersion)

        XCTAssertTrue(store.activateStagedIfIdle(isIdle: true))
        XCTAssertEqual(store.manifestVersion, 3)
        XCTAssertNil(store.stagedVersion)
        XCTAssertNotNil(store.url(forAsset: "chart.halo"))
        XCTAssertNotNil(store.url(forAsset: "sheet.halo"))
        XCTAssertNil(store.url(forAsset: "bgm.halo"), "audio is not prefetched")
        XCTAssertFalse(requested.contains { $0.hasSuffix(".m4a") })
        XCTAssertFalse(store.activateStagedIfIdle(isIdle: true), "nothing more to activate")
    }

    func testAStagedReleaseIsActivatedAtTheNextLaunch() async throws {
        let store = makeStore()
        await sync(store).sync(to: publish(version: 4).info)
        let relaunched = makeStore()
        relaunched.loadActive()
        XCTAssertEqual(relaunched.manifestVersion, 4)
        XCTAssertNil(relaunched.stagedVersion)
    }

    func testAHashMismatchDiscardsTheReleaseAndKeepsTheOldOne() async throws {
        let store = makeStore()
        await sync(store).sync(to: publish(version: 1).info)
        store.activateStagedIfIdle(isIdle: true)

        let syncer = sync(store)
        let ok = await syncer.sync(to: publish(version: 2, corruptAsset: true).info)
        XCTAssertFalse(ok)
        XCTAssertEqual(syncer.lastFailure, .verificationFailed("hash mismatch for assets/\(ManifestVerifier.sha256Hex(of: Data("chart-2".utf8))).json"))
        XCTAssertNil(store.stagedVersion)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.manifestsDirectory.appendingPathComponent("2.json").path))
        XCTAssertEqual(store.manifestVersion, 1)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: store.assetsDirectory.path)) ?? []
        XCTAssertFalse(leftovers.contains { $0.hasPrefix(ManifestVerifier.sha256Hex(of: Data("tampered".utf8))) })
    }

    func testABadSignatureAndAWrongManifestHashAreRejected() async throws {
        let store = makeStore()
        let a = sync(store)
        let badSig = await a.sync(to: publish(version: 5, badSignature: true).info)
        XCTAssertFalse(badSig)
        XCTAssertEqual(a.lastFailure, .verificationFailed("bad manifest signature"))
        let b = sync(store)
        let badHash = await b.sync(to: publish(version: 6, wrongHash: true).info)
        XCTAssertFalse(badHash)
        XCTAssertEqual(b.lastFailure, .verificationFailed("manifest hash differs from the bootstrap"))
        XCTAssertNil(store.stagedVersion)
    }

    func testAReleaseThatNeedsANewerAppOrSchemaIsIgnored() async throws {
        let store = makeStore()
        let a = sync(store, build: 57)
        let needsBuild = await a.sync(to: publish(version: 7, minBuild: 99).info)
        XCTAssertFalse(needsBuild)
        XCTAssertEqual(a.lastFailure, .incompatible)
        let b = sync(store, schema: 1)
        let needsSchema = await b.sync(to: publish(version: 8, schema: 2).info)
        XCTAssertFalse(needsSchema)
        XCTAssertEqual(b.lastFailure, .incompatible)
        XCTAssertNil(store.stagedVersion)
    }

    func testARollbackToALowerVersionIsAccepted() async throws {
        let store = makeStore()
        await sync(store).sync(to: publish(version: 9).info)
        store.activateStagedIfIdle(isIdle: true)
        XCTAssertEqual(store.manifestVersion, 9)
        await sync(store).sync(to: publish(version: 4).info)
        XCTAssertTrue(store.activateStagedIfIdle(isIdle: true))
        XCTAssertEqual(store.manifestVersion, 4)
    }

    func testTheSameVersionIsNotDownloadedTwice() async throws {
        let store = makeStore()
        let release = publish(version: 2)
        await sync(store).sync(to: release.info)
        let count = requested.count
        await sync(store).sync(to: release.info)
        XCTAssertEqual(requested.count, count)
        store.activateStagedIfIdle(isIdle: true)
        await sync(store).sync(to: release.info)
        XCTAssertEqual(requested.count, count)
    }

    func testTransientErrorsAreRetriedWithBackoffButA404IsNot() async throws {
        let store = makeStore()
        let release = publish(version: 3)
        let chartPath = "/assets/\(ManifestVerifier.sha256Hex(of: Data("chart-3".utf8))).json"
        failuresLeft[chartPath] = 2
        var waits: [UInt64] = []
        let downloader = AssetDownloader(session: StubURLProtocol.session(), sleep: { waits.append($0) })
        let ok = await ContentSync(store: store, downloader: downloader, verifier: verifier, supportedSchema: 1, build: { 57 }).sync(to: release.info)
        XCTAssertTrue(ok)
        XCTAssertEqual(waits, [1_000_000_000, 4_000_000_000])

        served.removeValue(forKey: chartPath)
        waits = []
        try? FileManager.default.removeItem(at: store.assetsDirectory)
        try? FileManager.default.removeItem(at: store.manifestsDirectory)
        store.markStaged(version: 0)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("Content/staged.json"))
        let failed = await ContentSync(store: store, downloader: downloader, verifier: verifier, supportedSchema: 1, build: { 57 }).sync(to: release.info)
        XCTAssertFalse(failed)
        XCTAssertEqual(waits, [], "404 is final")
    }

    func testAudioIsFetchedOnDemandAndVerified() async throws {
        let store = makeStore()
        let release = publish(version: 3)
        let syncer = sync(store)
        await syncer.sync(to: release.info)
        store.activateStagedIfIdle(isIdle: true)
        let url = try await syncer.ensureAsset("bgm.halo")
        XCTAssertEqual(try Data(contentsOf: url), Data("audio-3".utf8))
        XCTAssertEqual(store.url(forAsset: "bgm.halo"), url)
        // Asking again needs no download.
        let before = requested.count
        _ = try await syncer.ensureAsset("bgm.halo")
        XCTAssertEqual(requested.count, before)
        do {
            _ = try await syncer.ensureAsset("bgm.nope")
            XCTFail("unknown asset")
        } catch {}
    }

    func testOnDemandAudioThatFailsTheHashIsNeverKept() async throws {
        let store = makeStore()
        let release = publish(version: 3)
        let syncer = sync(store)
        await syncer.sync(to: release.info)
        store.activateStagedIfIdle(isIdle: true)
        served["/assets/\(ManifestVerifier.sha256Hex(of: Data("audio-3".utf8))).m4a"] = Data("wrong".utf8)
        do {
            _ = try await syncer.ensureAsset("bgm.halo")
            XCTFail("should fail")
        } catch let error as ContentError {
            guard case .verificationFailed = error else { return XCTFail("\(error)") }
        }
        XCTAssertNil(store.url(forAsset: "bgm.halo"))
    }

    func testGarbageCollectionKeepsTheTwoNewestAndTheActiveRelease() async throws {
        let store = makeStore()
        var assetNames: [Int: String] = [:]
        for v in 1...4 {
            await sync(store).sync(to: publish(version: v).info)
            assetNames[v] = "\(ManifestVerifier.sha256Hex(of: Data("chart-\(v)".utf8))).json"
            store.activateStagedIfIdle(isIdle: true)
        }
        store.collectGarbage()
        let manifests = try FileManager.default.contentsOfDirectory(atPath: store.manifestsDirectory.path)
        XCTAssertEqual(Set(manifests.filter { $0.hasSuffix(".json") }), ["3.json", "4.json"])
        let assets = Set(try FileManager.default.contentsOfDirectory(atPath: store.assetsDirectory.path))
        XCTAssertTrue(assets.contains(assetNames[4]!))
        XCTAssertTrue(assets.contains(assetNames[3]!))
        XCTAssertFalse(assets.contains(assetNames[1]!))
        XCTAssertFalse(assets.contains(assetNames[2]!))
    }

    func testTheContentFolderIsExcludedFromBackup() async throws {
        let store = makeStore()
        await sync(store).sync(to: publish(version: 1).info)
        store.activateStagedIfIdle(isIdle: true)
        let values = try dir.appendingPathComponent("Content").resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testActivationAnnouncesTheChangeSoCachesCanBeDropped() async throws {
        let store = makeStore()
        await sync(store).sync(to: publish(version: 1).info)
        let announced = expectation(forNotification: .contentStoreDidActivate, object: store)
        store.activateStagedIfIdle(isIdle: true)
        await fulfillment(of: [announced], timeout: 2)
    }
}
