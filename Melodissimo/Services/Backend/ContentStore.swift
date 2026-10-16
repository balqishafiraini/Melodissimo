//
//  ContentStore.swift
//  Melodissimo
//
//  The active content pack: songs, packs, shop items, products and the files behind them. Resolution order for every
//  asset (`BACKEND_PLAN.md` §5.2): the downloaded pack, then the bundled baseline, then nothing (callers fall back to the
//  legacy bundle files). Reads are synchronous and fast; downloading is Task B6.2.
//
//  Layout on disk: `Application Support/Content/active.json` = `{ "version": 12 }`, `manifests/<version>.json` (+ `.sig`),
//  `assets/<sha256>.<ext>`.
//

import Foundation

/// The bundled pack the app ships with, so it works offline on first launch.
protocol ContentBaseline {
    var manifestData: Data? { get }
    var signature: String? { get }
    /// The file for an asset: Xcode flattens bundle folders, so it is looked up by `<sha256>.<ext>`.
    func assetURL(sha256: String, fileExtension: String) -> URL?
}

struct BundleBaseline: ContentBaseline {
    var bundle: Bundle = .main

    private func url(_ name: String, _ ext: String) -> URL? {
        bundle.url(forResource: name, withExtension: ext)
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Data/Content/baseline")
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "baseline")
    }

    var manifestData: Data? { url("manifest", "json").flatMap { try? Data(contentsOf: $0) } }
    var signature: String? { url("manifest.json", "sig").flatMap { try? String(contentsOf: $0, encoding: .utf8) } }

    func assetURL(sha256: String, fileExtension: String) -> URL? {
        url(sha256, fileExtension) ?? bundle.url(forResource: sha256, withExtension: fileExtension, subdirectory: "assets")
    }
}

extension Notification.Name {
    /// Posted on the main thread whenever the active pack changes, so caches built from it (songs, charts) are dropped.
    static let contentStoreDidActivate = Notification.Name("melodissimo.contentStoreDidActivate")
}

final class ContentStore: ObservableObject {

    static let shared = ContentStore()

    /// One loaded and verified manifest.
    struct Loaded {
        var manifest: ContentManifest
    }

    private let root: URL
    private let baseline: ContentBaseline
    private let verifier: ManifestVerifier
    private let build: () -> Int
    private let lock = NSLock()
    private var active: Loaded?
    private var baselinePack: Loaded?
    private var activeCDN: URL?

    init(root: URL = ContentStore.defaultRoot,
         baseline: ContentBaseline = BundleBaseline(),
         verifier: ManifestVerifier = ManifestVerifier(),
         build: @escaping () -> Int = { ShopCatalog.currentBuild }) {
        self.root = root
        self.baseline = baseline
        self.verifier = verifier
        self.build = build
    }

    nonisolated static var defaultRoot: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Content")
    }

    var assetsDirectory: URL { root.appendingPathComponent("assets") }
    var manifestsDirectory: URL { root.appendingPathComponent("manifests") }
    private var activePointer: URL { root.appendingPathComponent("active.json") }

    // MARK: Loading

    /// Reads the active downloaded pack (verifying its signature again, which is cheap) and the baseline. A pack that
    /// fails verification is ignored, so the baseline is used instead.
    func loadActive() {
        // A release downloaded last time is activated now: launch is a safe moment (no song is playing).
        if let staged = readPointer(stagedPointer), loadDownloaded(version: staged.version) != nil {
            _ = writeActivePointer(staged.version, cdnBase: staged.cdnBase)
            try? FileManager.default.removeItem(at: stagedPointer)
        }
        let loadedActive = readActive()
        let loadedBaseline = readBaseline()
        lock.withLock {
            active = loadedActive
            baselinePack = loadedBaseline
        }
        notifyChange()
    }

    private func readBaseline() -> Loaded? {
        guard let data = baseline.manifestData, let signature = baseline.signature,
              verifier.verifySignature(of: data, signature: signature),
              let manifest = try? ContentManifest.decode(data) else { return nil }
        return Loaded(manifest: manifest)
    }

    /// `active.json` and `staged.json`: which version, and the CDN it came from (to fetch audio on demand later).
    private struct Pointer: Codable {
        let version: Int
        let cdnBase: String?
    }

    private func readPointer(_ url: URL) -> Pointer? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Pointer.self, from: $0) }
    }

    private func readActive() -> Loaded? {
        guard let pointer = readPointer(activePointer), let loaded = loadDownloaded(version: pointer.version) else {
            lock.withLock { activeCDN = nil }
            return nil
        }
        lock.withLock { activeCDN = pointer.cdnBase.flatMap(URL.init(string:)) }
        return loaded
    }

    /// A downloaded manifest by version, only if its signature is valid.
    func loadDownloaded(version: Int) -> Loaded? {
        let file = manifestsDirectory.appendingPathComponent("\(version).json")
        guard let data = try? Data(contentsOf: file),
              let signature = try? String(contentsOf: file.appendingPathExtension("sig"), encoding: .utf8),
              verifier.verifySignature(of: data, signature: signature),
              let manifest = try? ContentManifest.decode(data) else { return nil }
        return Loaded(manifest: manifest)
    }

    /// Makes a downloaded version the active one (the caller has verified and staged it).
    func activate(version: Int, cdnBase: URL? = nil) -> Bool {
        guard let loaded = loadDownloaded(version: version), writeActivePointer(version, cdnBase: cdnBase?.absoluteString) else { return false }
        lock.withLock {
            active = loaded
            activeCDN = cdnBase
        }
        notifyChange()
        return true
    }

    private func writeActivePointer(_ version: Int, cdnBase: String?) -> Bool {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try JSONEncoder().encode(Pointer(version: version, cdnBase: cdnBase)).write(to: activePointer, options: .atomic)
            // Downloaded content is not part of the player's backup: it can always be fetched again.
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var folder = root
            try? folder.setResourceValues(values)
            return true
        } catch {
            return false
        }
    }

    /// The version of the active downloaded pack, if any.
    var activeVersion: Int? { lock.withLock { active?.manifest.contentVersion } }

    private func notifyChange() {
        let post = {
            self.objectWillChange.send()
            NotificationCenter.default.post(name: .contentStoreDidActivate, object: self)
        }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
    }

    // MARK: Staging

    private var stagedPointer: URL { root.appendingPathComponent("staged.json") }

    /// A release that is downloaded and verified but not yet in use. It is activated at the next launch, or by
    /// `activateStagedIfIdle()` when Home is showing and no song is playing (`BACKEND_PLAN.md` §3.4 invariant 4).
    var stagedVersion: Int? { readPointer(stagedPointer)?.version }

    func markStaged(version: Int, cdnBase: URL? = nil) {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? JSONEncoder().encode(Pointer(version: version, cdnBase: cdnBase?.absoluteString)).write(to: stagedPointer, options: .atomic)
    }

    /// Activates the staged release when nothing is playing. Returns whether the pack changed.
    @discardableResult
    func activateStagedIfIdle(isIdle: Bool = !PlaySession.isActive) -> Bool {
        guard isIdle, let pointer = readPointer(stagedPointer), pointer.version != activeVersion else { return false }
        guard activate(version: pointer.version, cdnBase: pointer.cdnBase.flatMap(URL.init(string:))) else { return false }
        try? FileManager.default.removeItem(at: stagedPointer)
        return true
    }

    // MARK: Garbage collection

    /// Deletes downloaded manifests older than the two newest (and the active one) and every asset none of the kept
    /// manifests refers to. Run once per launch, off the main thread.
    func collectGarbage() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: manifestsDirectory, includingPropertiesForKeys: nil)) ?? []
        let versions = files.compactMap { Int($0.deletingPathExtension().lastPathComponent) }
            .filter { $0 >= 0 && files.contains(manifestsDirectory.appendingPathComponent("\($0).json")) }
        var keep = Set(versions.sorted(by: >).prefix(2))
        if let active = activeVersion { keep.insert(active) }
        if let staged = stagedVersion { keep.insert(staged) }
        for v in Set(versions).subtracting(keep) {
            try? fm.removeItem(at: manifestsDirectory.appendingPathComponent("\(v).json"))
            try? fm.removeItem(at: manifestsDirectory.appendingPathComponent("\(v).json.sig"))
        }
        var referenced = Set<String>()
        for v in keep {
            guard let manifest = loadDownloaded(version: v)?.manifest else { continue }
            for asset in manifest.assets.values { referenced.insert("\(asset.sha256).\(asset.fileExtension)") }
        }
        let stored = (try? fm.contentsOfDirectory(at: assetsDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in stored where !referenced.contains(file.lastPathComponent) { try? fm.removeItem(at: file) }
    }

    // MARK: Reading

    private var current: Loaded? { lock.withLock { active ?? baselinePack } }

    var manifestVersion: Int? { current?.manifest.contentVersion }

    /// The songs the app may show: not hidden, not unknown, and built for this app.
    var songs: [ManifestSong] {
        let build = build()
        return (current?.manifest.songs ?? [])
            .filter { $0.status != .hidden && $0.minAppBuild <= build }
            .sorted { ($0.order, $0.id) < ($1.order, $1.id) }
    }

    var packs: [ManifestPack] { current?.manifest.packs ?? [] }
    var shopItems: [ShopItem] { current?.manifest.shopItems ?? [] }
    var products: [StoreProduct] { current?.manifest.products ?? [] }

    /// The file for an asset key (`chart.<slug>`, `bgm.<slug>`, `sheet.<slug>`, `art.…`): the downloaded one, else the
    /// baseline's, else `nil`.
    func url(forAsset key: String) -> URL? {
        let (activePack, basePack) = lock.withLock { (active, baselinePack) }
        if let asset = activePack?.manifest.assets[key] {
            let file = assetsDirectory.appendingPathComponent("\(asset.sha256).\(asset.fileExtension)")
            if FileManager.default.fileExists(atPath: file.path) { return file }
            // The active pack lists it but it isn't downloaded yet: the baseline's copy of the same asset, if any.
            if let url = baseline.assetURL(sha256: asset.sha256, fileExtension: asset.fileExtension) { return url }
        }
        if let asset = basePack?.manifest.assets[key] {
            return baseline.assetURL(sha256: asset.sha256, fileExtension: asset.fileExtension)
        }
        return nil
    }

    /// The asset's manifest entry and the CDN to download it from, for an asset of the active pack that isn't on disk.
    func assetAndBase(forKey key: String) -> (ManifestAsset, URL)? {
        let (pack, cdn) = lock.withLock { (active, activeCDN) }
        guard let asset = pack?.manifest.assets[key], let base = cdn ?? BackendEnvironment.cdnBaseURL else { return nil }
        return (asset, base)
    }

    /// Whether an asset is available to read right now.
    func hasAsset(_ key: String) -> Bool { url(forAsset: key) != nil }
}
