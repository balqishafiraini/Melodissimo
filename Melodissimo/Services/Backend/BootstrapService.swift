//
//  BootstrapService.swift
//  Melodissimo
//
//  Fetches `/v1/bootstrap`, caches it on disk and publishes what it says: the update directive, maintenance, flags and
//  tuning. The app never waits for it: with no network the cached copy is used, and with no cache the code defaults
//  (`BACKEND_PLAN.md` §5.1, invariant 3).
//

import Foundation
import UIKit

/// What `FeatureFlags` and `Tuning` read: the latest values from the bootstrap, safe to read from any thread.
enum LiveConfig {
    private static let lock = NSLock()
    private static var storedFlags: [String: Bool] = [:]
    private static var storedTuning: [String: JSONValue] = [:]

    static var flags: [String: Bool] { lock.withLock { storedFlags } }
    static var tuning: [String: JSONValue] { lock.withLock { storedTuning } }

    static func set(flags: [String: Bool], tuning: [String: JSONValue]) {
        lock.withLock {
            storedFlags = flags
            storedTuning = tuning
        }
    }
}

/// A bootstrap as stored on disk, with the time it was fetched so the TTL can be checked after a relaunch.
struct CachedBootstrap: Codable, Equatable {
    var fetchedAt: Date
    var bootstrap: Bootstrap
}

@MainActor
final class BootstrapService: ObservableObject {

    static let shared = BootstrapService()

    @Published private(set) var current: Bootstrap?
    @Published private(set) var directive: UpdateDirective = .none
    @Published private(set) var maintenance: Bootstrap.MaintenanceInfo?

    /// Seconds a launch may wait for the very first answer, and for later ones.
    static let firstLaunchTimeout: TimeInterval = 1.5
    static let normalTimeout: TimeInterval = 8

    private let makeClient: () -> APIClient
    private let cacheURL: URL
    private let build: Int
    private let now: () -> Date
    private let isPlaying: () -> Bool
    private let isEnabled: () -> Bool
    private var fetchedAt: Date?
    private var isRefreshing = false
    private var observer: NSObjectProtocol?
    /// Called after each successful refresh with the release the server names (nil when none is compatible).
    var onContent: ((Bootstrap.ContentInfo?) -> Void)?

    init(makeClient: @escaping () -> APIClient = { APIClient() },
         cacheURL: URL = BootstrapService.defaultCacheURL,
         build: Int = ClientHeaders.current().build,
         now: @escaping () -> Date = Date.init,
         isPlaying: @escaping () -> Bool = { PlaySession.isActive },
         isEnabled: @escaping () -> Bool = { BackendEnvironment.isEnabled }) {
        self.makeClient = makeClient
        self.cacheURL = cacheURL
        self.build = build
        self.now = now
        self.isPlaying = isPlaying
        self.isEnabled = isEnabled
    }

    nonisolated static var defaultCacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Backend/bootstrap.json")
    }

    // MARK: Launch

    /// Called once at launch: reads the cache at once, then refreshes in the background and again whenever the app
    /// returns to the foreground. Does nothing when the backend is switched off.
    func start() {
        guard isEnabled() else { return }
        loadCached()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    /// Reads the last bootstrap from disk (synchronous, fast). The update directive is recomputed from the cached
    /// policy and this build, so a hard block holds even offline.
    func loadCached() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? Self.decoder.decode(CachedBootstrap.self, from: data) else { return }
        fetchedAt = cached.fetchedAt
        apply(cached.bootstrap)
    }

    // MARK: Refresh

    /// Fetches a fresh bootstrap unless the cached one is still within its TTL (or `force`), a play screen is open,
    /// or a refresh is already running. A failure leaves the cached values in place.
    func refresh(force: Bool = false) async {
        guard isEnabled(), !isRefreshing, !isPlaying() else { return }
        if !force, let current, let fetchedAt, now().timeIntervalSince(fetchedAt) < Double(current.ttlSeconds) { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let timeout = current == nil ? Self.firstLaunchTimeout : Self.normalTimeout
        guard let fresh: Bootstrap = try? await makeClient().get("v1/bootstrap", timeout: timeout) else { return }
        let stamp = now()
        fetchedAt = stamp
        save(CachedBootstrap(fetchedAt: stamp, bootstrap: fresh))
        apply(fresh)
        onContent?(fresh.content)
    }

    // MARK: State

    private func apply(_ bootstrap: Bootstrap) {
        current = bootstrap
        directive = Self.directive(for: bootstrap, build: build)
        maintenance = bootstrap.maintenance
        LiveConfig.set(flags: bootstrap.flags ?? [:], tuning: bootstrap.tuning ?? [:])
    }

    /// From the policy when there is one, otherwise from the action the server sent. An unknown action means no block.
    static func directive(for bootstrap: Bootstrap, build: Int) -> UpdateDirective {
        guard let update = bootstrap.update else { return .none }
        if let policy = update.policy { return UpdateDirective.decide(build: build, policy: policy) }
        switch update.action {
        case .hard: return .hard
        case .soft: return .soft
        case .none, .unknown: return .none
        }
    }

    private func save(_ cached: CachedBootstrap) {
        do {
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(cached).write(to: cacheURL, options: .atomic)
        } catch {
            // The cache is an optimisation; a full disk must not break the app.
        }
    }

    private static let decoder = APIClient.makeDecoder()
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
