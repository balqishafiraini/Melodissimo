//
//  AssetDownloader.swift
//  Melodissimo
//
//  Downloads a content release (`BACKEND_PLAN.md` §5.2): the manifest and signature, then the files it needs, each
//  checked against its SHA-256 before it is kept. A release that fails any check is thrown away and the app keeps what
//  it has.
//

import Foundation

enum ContentError: Error, Equatable {
    case download(String)
    /// A hash or the signature didn't match: never keep the release.
    case verificationFailed(String)
    /// The release needs a newer app, or a newer content schema than this binary reads.
    case incompatible
}

struct AssetDownloader {
    let session: URLSession
    /// How long to wait between attempts (1 s, 4 s, 16 s). Tests pass a no-op.
    var sleep: (UInt64) async -> Void = { try? await Task.sleep(nanoseconds: $0) }
    static let backoff: [UInt64] = [1_000_000_000, 4_000_000_000, 16_000_000_000]
    static let maxConcurrent = 3

    init(session: URLSession = APIClient.defaultSession, sleep: @escaping (UInt64) async -> Void = { try? await Task.sleep(nanoseconds: $0) }) {
        self.session = session
        self.sleep = sleep
    }

    /// The CDN root of a manifest URL (`https://cdn/manifests/12.json` → `https://cdn`).
    static func cdnBase(ofManifestURL url: URL) -> URL {
        url.deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Downloads a URL with up to three retries (1 s, 4 s, 16 s), but not for a 4xx answer, which won't change.
    func data(from url: URL) async throws -> Data {
        var attempt = 0
        while true {
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse else { throw ContentError.download("no response") }
                if (200..<300).contains(http.statusCode) { return data }
                if (400..<500).contains(http.statusCode) { throw ContentError.download("HTTP \(http.statusCode) for \(url.lastPathComponent)") }
                throw URLError(.badServerResponse)
            } catch let error as ContentError {
                throw error
            } catch {
                guard attempt < Self.backoff.count else { throw ContentError.download((error as NSError).localizedDescription) }
                await sleep(Self.backoff[attempt])
                attempt += 1
            }
        }
    }

    /// Downloads one asset, checks its hash and moves it to `<directory>/<sha256>.<ext>`.
    func downloadAsset(_ asset: ManifestAsset, base: URL, into directory: URL) async throws {
        guard let url = URL(string: asset.path, relativeTo: base)?.absoluteURL else { throw ContentError.download("bad path \(asset.path)") }
        let data = try await data(from: url)
        guard ManifestVerifier.sha256Hex(of: data) == asset.sha256.lowercased() else {
            throw ContentError.verificationFailed("hash mismatch for \(asset.path)")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("\(asset.sha256).\(asset.fileExtension)")
        try data.write(to: destination, options: .atomic)
    }

    /// Downloads many assets, at most three at a time. Stops at the first failure.
    func downloadAll(_ assets: [ManifestAsset], base: URL, into directory: URL) async throws {
        var pending = assets[...]
        try await withThrowingTaskGroup(of: Void.self) { group in
            func next() {
                guard let asset = pending.popFirst() else { return }
                group.addTask { try await downloadAsset(asset, base: base, into: directory) }
            }
            for _ in 0..<Self.maxConcurrent { next() }
            while try await group.next() != nil { next() }
        }
    }
}

/// Brings the app's content up to the release the bootstrap names: stage it (download and verify), then activate it
/// when it is safe.
final class ContentSync {

    static let shared = ContentSync()

    private let store: ContentStore
    private let downloader: AssetDownloader
    private let verifier: ManifestVerifier
    private let supportedSchema: Int
    private let build: () -> Int
    /// Ids of shop items the player owns or wears: their downloaded art is fetched with the release, the rest later.
    private let ownedItemIds: () -> Set<String>
    private var isSyncing = false
    private let lock = NSLock()

    /// Set when a release was rejected (hash, signature, compatibility); the app logs it as `content_verify_failed`.
    private(set) var lastFailure: ContentError?

    init(store: ContentStore = .shared, downloader: AssetDownloader = AssetDownloader(), verifier: ManifestVerifier = ManifestVerifier(),
         supportedSchema: Int = ClientHeaders.supportedSchemaVersion, build: @escaping () -> Int = { ShopCatalog.currentBuild },
         ownedItemIds: @escaping () -> Set<String> = ContentSync.ownedAndEquippedItemIds) {
        self.store = store
        self.downloader = downloader
        self.verifier = verifier
        self.supportedSchema = supportedSchema
        self.build = build
        self.ownedItemIds = ownedItemIds
    }

    /// Everything the player has bought plus what they are wearing now.
    static func ownedAndEquippedItemIds() -> Set<String> {
        let progress = ProgressStore.shared
        return progress.purchasedShopItemIds.union(ShopCategory.equippable.map { progress.equippedItem($0).id })
    }

    /// Stages the release in `info` if the app isn't on it already. Never throws: a failure keeps the old content.
    /// Returns whether a release is now staged or active at that version.
    @discardableResult
    func sync(to info: Bootstrap.ContentInfo) async -> Bool {
        guard begin() else { return false }
        defer { end() }
        let version = info.version
        // Rolling back to a lower version is accepted: the server decides.
        if store.activeVersion == version || (store.activeVersion == nil && store.manifestVersion == version) { return true }
        if store.stagedVersion == version, store.loadDownloaded(version: version) != nil { return true }
        guard let manifestURL = URL(string: info.manifestUrl), let signatureURL = URL(string: info.signatureUrl) else { return false }

        do {
            let manifestData = try await downloader.data(from: manifestURL)
            guard ManifestVerifier.sha256Hex(of: manifestData) == info.sha256.lowercased() else {
                throw ContentError.verificationFailed("manifest hash differs from the bootstrap")
            }
            let signature = String(decoding: try await downloader.data(from: signatureURL), as: UTF8.self)
            guard verifier.verifySignature(of: manifestData, signature: signature) else {
                throw ContentError.verificationFailed("bad manifest signature")
            }
            let manifest = try ContentManifest.decode(manifestData)
            guard manifest.contentVersion == version else { throw ContentError.verificationFailed("manifest is version \(manifest.contentVersion), expected \(version)") }
            guard manifest.schemaVersion <= supportedSchema, manifest.minAppBuildIos <= build() else { throw ContentError.incompatible }

            // Everything marked `prefetch` that isn't on disk yet (audio is fetched when a song is opened).
            let base = AssetDownloader.cdnBase(ofManifestURL: manifestURL)
            let missing = manifest.assets.values.filter { asset in
                asset.prefetch == true
                    && !FileManager.default.fileExists(atPath: store.assetsDirectory.appendingPathComponent("\(asset.sha256).\(asset.fileExtension)").path)
            }
            // Art of owned and worn items comes along (it isn't `prefetch`, since the manifest doesn't know the player).
            let owned = ownedItemIds()
            let ownedArt = ShopCatalog.artKeys(of: manifest.shopItems.filter { owned.contains($0.id) }).compactMap { manifest.assets[$0] }
            var wanted: [String: ManifestAsset] = [:]
            for asset in Array(missing) + ownedArt
            where !FileManager.default.fileExists(atPath: store.assetsDirectory.appendingPathComponent("\(asset.sha256).\(asset.fileExtension)").path) {
                wanted[asset.sha256] = asset
            }
            try await downloader.downloadAll(Array(wanted.values), base: base, into: store.assetsDirectory)

            // The manifest is written last, so a half-downloaded release can never be activated.
            try FileManager.default.createDirectory(at: store.manifestsDirectory, withIntermediateDirectories: true)
            let file = store.manifestsDirectory.appendingPathComponent("\(version).json")
            try manifestData.write(to: file, options: .atomic)
            try signature.write(to: file.appendingPathExtension("sig"), atomically: true, encoding: .utf8)
            store.markStaged(version: version, cdnBase: base)
            lastFailure = nil
            return true
        } catch let error as ContentError {
            lastFailure = error
            discard(version: version)
            return false
        } catch {
            lastFailure = .download((error as NSError).localizedDescription)
            return false
        }
    }

    /// Fetches one asset of the active pack on demand (a song's backing track) and returns its file.
    func ensureAsset(_ key: String) async throws -> URL {
        if let url = store.url(forAsset: key) { return url }
        guard let (asset, base) = store.assetAndBase(forKey: key) else { throw ContentError.download("unknown asset \(key)") }
        try await downloader.downloadAsset(asset, base: base, into: store.assetsDirectory)
        guard let url = store.url(forAsset: key) else { throw ContentError.download("asset \(key) is missing after download") }
        store.assetsDidChange()
        return url
    }

    private func discard(version: Int) {
        let file = store.manifestsDirectory.appendingPathComponent("\(version).json")
        try? FileManager.default.removeItem(at: file)
        try? FileManager.default.removeItem(at: file.appendingPathExtension("sig"))
    }

    private func begin() -> Bool {
        lock.withLock {
            guard !isSyncing else { return false }
            isSyncing = true
            return true
        }
    }

    private func end() { lock.withLock { isSyncing = false } }
}
