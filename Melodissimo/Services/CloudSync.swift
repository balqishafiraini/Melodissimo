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

/// Mirrors the progress keys (§3.4) to iCloud key-value storage and merges what other devices
/// write, using `CloudMerge`. It does nothing when the player isn't signed in to iCloud or the
/// app lacks the iCloud key-value entitlement (then the cloud store simply stays empty).
final class CloudSync {
    static let shared = CloudSync()

    private let local: SyncStore
    private let cloud: SyncStore
    private let songTitles: Set<String>
    private var isSyncing = false
    private var pending: DispatchWorkItem?

    init(local: SyncStore = DefaultsSyncStore(),
         cloud: SyncStore = CloudSyncStore(),
         songTitles: Set<String> = Set(SongLibrary.all.map(\.title))) {
        self.local = local
        self.cloud = cloud
        self.songTitles = songTitles
    }

    /// Merges now and keeps merging: when another device writes, and shortly after this one does.
    /// Call once at launch.
    func start() {
        guard FileManager.default.ubiquityIdentityToken != nil else { return }
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
        guard !isSyncing else { return [] }
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
        for key in cloud.snapshot().keys where CloudMerge.isSynced(key, songTitles: songTitles) {
            cloud.remove(forKey: key)
        }
        (cloud as? CloudSyncStore)?.synchronize()
    }

    private func scheduleSync() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.sync() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
    }
}
