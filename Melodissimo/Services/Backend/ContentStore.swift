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

    private func readActive() -> Loaded? {
        struct Pointer: Decodable { let version: Int }
        guard let pointerData = try? Data(contentsOf: activePointer),
              let version = (try? JSONDecoder().decode(Pointer.self, from: pointerData))?.version,
              let loaded = loadDownloaded(version: version) else { return nil }
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
    func activate(version: Int) -> Bool {
        guard let loaded = loadDownloaded(version: version) else { return false }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try JSONEncoder().encode(["version": version]).write(to: activePointer, options: .atomic)
        } catch {
            return false
        }
        lock.withLock { active = loaded }
        notifyChange()
        return true
    }

    private func notifyChange() {
        if Thread.isMainThread { objectWillChange.send() } else { DispatchQueue.main.async { self.objectWillChange.send() } }
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

    /// Whether an asset is available to read right now.
    func hasAsset(_ key: String) -> Bool { url(forAsset: key) != nil }
}
