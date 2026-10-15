//
//  CloudSync.swift
//  Melodissimo
//

import Foundation

/// A key-value store `CloudSync` can read and write; `UserDefaults` and `NSUbiquitousKeyValueStore`
/// are wrapped so tests can use dictionaries instead.
protocol SyncStore: AnyObject {
    func snapshot() -> [String: Any]
    func set(_ value: Any, forKey key: String)
    func remove(forKey key: String)
}

final class DefaultsSyncStore: SyncStore {
    private let defaults: UserDefaults
    init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    func snapshot() -> [String: Any] { defaults.dictionaryRepresentation() }
    func set(_ value: Any, forKey key: String) { defaults.set(value, forKey: key) }
    func remove(forKey key: String) { defaults.removeObject(forKey: key) }
}

final class CloudSyncStore: SyncStore {
    private let store: NSUbiquitousKeyValueStore
    init(_ store: NSUbiquitousKeyValueStore = .default) { self.store = store }
    func snapshot() -> [String: Any] { store.dictionaryRepresentation }
    func set(_ value: Any, forKey key: String) { store.set(value, forKey: key) }
    func remove(forKey key: String) { store.removeObject(forKey: key) }
    func synchronize() { store.synchronize() }
}

/// Whether the app may talk to Game Center and iCloud. Both need capabilities (entitlements) that the
/// current signing profile doesn't have, and calling them anyway makes the system log errors and burn CPU
/// at launch. So they run only when the Info.plist key `MelodissimoOnlineServices` is `YES`; see
/// `STABILITY_PLAN.md` §7 for how to switch them on.
enum OnlineServices {
    static var isEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "MelodissimoOnlineServices") as? Bool ?? false
    }
}

/// Mirrors the progress keys (§3.4) to iCloud key-value storage and merges what other devices
/// write, using `CloudMerge`. It does nothing unless online services are switched on and the player is
/// signed in to iCloud. The cloud store is created lazily, so `NSUbiquitousKeyValueStore` is never even
/// touched on a build without the iCloud key-value entitlement.
final class CloudSync {
    static let shared = CloudSync()

    private let local: SyncStore
    private let makeCloud: () -> SyncStore
    private lazy var cloud: SyncStore = makeCloud()
    private let isEnabled: () -> Bool
    private let songTitles: Set<String>
    private var isSyncing = false
    private var pending: DispatchWorkItem?

    /// `cloudFactory` runs at most once, the first time the cloud store is needed.
    init(local: SyncStore = DefaultsSyncStore(),
         cloudFactory: @escaping () -> SyncStore = { CloudSyncStore() },
         isEnabled: @escaping () -> Bool = { OnlineServices.isEnabled },
         songTitles: Set<String> = Set(SongLibrary.all.map(\.title))) {
        self.local = local
        self.makeCloud = cloudFactory
        self.isEnabled = isEnabled
        self.songTitles = songTitles
    }

    /// An already-built cloud store (tests pass a dictionary). Always enabled.
    convenience init(local: SyncStore, cloud: SyncStore,
                     songTitles: Set<String> = Set(SongLibrary.all.map(\.title))) {
        self.init(local: local, cloudFactory: { cloud }, isEnabled: { true }, songTitles: songTitles)
    }

    /// Merges now and keeps merging: when another device writes, and shortly after this one does.
    /// Call once at launch.
    func start() {
        guard isEnabled(), FileManager.default.ubiquityIdentityToken != nil else { return }
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.sync() }
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.scheduleSync() }
        (cloud as? CloudSyncStore)?.synchronize()
        sync()
    }

    /// One merge pass in both directions. Returns the keys changed on this device.
    @discardableResult
    func sync() -> [String] {
        guard isEnabled(), !isSyncing else { return [] }
        isSyncing = true
        defer { isSyncing = false }

        let remote = cloud.snapshot().filter { CloudMerge.isSynced($0.key, songTitles: songTitles) }
        let mine = local.snapshot().filter { CloudMerge.isSynced($0.key, songTitles: songTitles) }
        let result = CloudMerge.merge(local: mine, remote: remote, songTitles: songTitles)

        for (key, value) in result.remote { cloud.set(value, forKey: key) }
        for (key, value) in result.local { local.set(value, forKey: key) }
        (cloud as? CloudSyncStore)?.synchronize()

        if !result.local.isEmpty {
            DispatchQueue.main.async {
                ProgressStore.shared.objectWillChange.send()
                AchievementStore.shared.reload()
            }
        }
        return Array(result.local.keys)
    }

    /// After "Reset progress": remove the synced keys from iCloud as well, so the old progress isn't
    /// merged straight back. (Another device that still holds it can bring it back.)
    func forgetProgress() {
        guard isEnabled() else { return }
        for key in cloud.snapshot().keys where CloudMerge.isSynced(key, songTitles: songTitles) {
            cloud.remove(forKey: key)
        }
        (cloud as? CloudSyncStore)?.synchronize()
    }

    /// Schedules one merge a few seconds from now (a later call replaces it). A play screen ends with this
    /// call, since writes made during play don't schedule anything.
    func syncSoon() {
        guard isEnabled() else { return }
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.sync() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: item)
    }

    /// Any defaults write lands here. Merging walks the whole defaults dictionary, which would stutter a
    /// song, so nothing is scheduled while a play screen is open.
    private func scheduleSync() {
        guard !PlaySession.isActive else { return }
        syncSoon()
    }
}
