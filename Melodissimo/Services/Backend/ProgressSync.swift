//
//  ProgressSync.swift
//  Melodissimo
//
//  Progress follows a signed-in player to other devices through the backend (`BACKEND_PLAN.md` Task B8.2). It uses the same merge
//  rules as the iCloud mirror (`CloudMerge`), so the two converge: numbers keep the larger value, flags are OR-ed, owned items
//  are unioned, the streak goes to whoever played last. The server stores one document per player and merges what it receives.
//

import Foundation
import UIKit

/// One synced value with the rule that merges it, as the server stores it.
struct ProgressEntry: Codable, Equatable {
    var r: String
    var v: JSONValue
}

/// Converts between the app's `UserDefaults` values and the server's document.
enum ProgressDocument {

    /// The streak pair travels as one entry.
    static let streakKey = "__streak"

    private static func ruleName(_ rule: CloudMerge.Rule) -> String {
        switch rule {
        case .max: return "max"
        case .earliest: return "earliest"
        case .or: return "or"
        case .union: return "union"
        case .keepLocal: return "keepLocal"
        }
    }

    private static func isBool(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static let dateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()

    /// The document for this device's synced keys (`snapshot` is a copy of `UserDefaults`).
    static func entries(from snapshot: [String: Any], songTitles: Set<String>) -> [String: ProgressEntry] {
        var out: [String: ProgressEntry] = [:]
        for (key, value) in snapshot where !CloudMerge.streakKeys.contains(key) {
            guard let rule = CloudMerge.rule(for: key, songTitles: songTitles) else { continue }
            switch rule {
            case .max, .earliest:
                guard let number = value as? NSNumber, !isBool(number) else { continue }
                out[key] = ProgressEntry(r: ruleName(rule), v: .number(number.doubleValue))
            case .or:
                guard let number = value as? NSNumber, isBool(number) else { continue }
                out[key] = ProgressEntry(r: ruleName(rule), v: .bool(number.boolValue))
            case .union:
                guard let list = value as? [String] else { continue }
                out[key] = ProgressEntry(r: ruleName(rule), v: .array(list.sorted().map(JSONValue.string)))
            case .keepLocal:
                guard let text = value as? String else { continue }
                out[key] = ProgressEntry(r: ruleName(rule), v: .string(text))
            }
        }
        if let date = snapshot["lastPlayedDate"] as? Date {
            let streak = (snapshot["currentStreak"] as? NSNumber)?.intValue ?? 0
            out[streakKey] = ProgressEntry(r: "streak", v: .object(["currentStreak": .number(Double(streak)),
                                                                     "lastPlayedDate": .string(dateFormatter.string(from: date))]))
        }
        return out
    }

    /// The server's document as `UserDefaults`-style values (the streak entry becomes its two keys), for `CloudMerge`.
    static func values(from entries: [String: ProgressEntry]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, entry) in entries {
            switch (entry.r, entry.v) {
            case ("streak", .object(let fields)):
                if case .number(let streak)? = fields["currentStreak"], case .string(let text)? = fields["lastPlayedDate"],
                   let date = dateFormatter.date(from: text) {
                    out["currentStreak"] = Int(streak)
                    out["lastPlayedDate"] = date
                }
            case (_, .number(let n)):
                out[key] = n == n.rounded() && abs(n) < 1e15 ? NSNumber(value: Int(n)) : NSNumber(value: n)
            case (_, .bool(let b)): out[key] = b
            case (_, .string(let s)): out[key] = s
            case (_, .array(let items)): out[key] = items.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
            default: break
            }
        }
        return out
    }
}

final class ProgressSyncService {

    static let shared = ProgressSyncService()

    private struct Document: Codable, Equatable {
        var data: [String: ProgressEntry]
        var revision: Int
    }
    private struct PutBody: Encodable { let data: [String: ProgressEntry] }

    private let local: SyncStore
    private let makeClient: () -> APIClient
    private let isEnabled: () -> Bool
    private let songTitles: () -> Set<String>
    private let lock = NSLock()
    private var isSyncing = false
    private var lastRun: Date?
    private var observer: NSObjectProtocol?

    /// Syncs again whenever the app returns to the foreground, at most every five minutes. Call once at launch.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            if let last = self.lastRun, Date().timeIntervalSince(last) < 300 { return }
            Task { await self.sync() }
        }
    }

    init(local: SyncStore = DefaultsSyncStore(),
         makeClient: @escaping () -> APIClient = { APIClient(authorization: { KeychainStore().read("playerToken") }) },
         isEnabled: @escaping () -> Bool = { BackendEnvironment.isEnabled && FeatureFlags.isOn(.accounts) && KeychainStore().read("playerToken") != nil },
         songTitles: @escaping () -> Set<String> = { Set(SongLibrary.all.map(\.title)) }) {
        self.local = local
        self.makeClient = makeClient
        self.isEnabled = isEnabled
        self.songTitles = songTitles
    }

    /// One round with the server: read, merge into this device, write the merged document back. A 409 (another device wrote
    /// meanwhile) merges its copy and tries again, up to three times. Returns whether the device and the server now agree.
    @discardableResult
    func sync() async -> Bool {
        guard isEnabled(), begin() else { return false }
        defer { end() }
        lastRun = Date()
        let client = makeClient()
        guard var document: Document = try? await client.get("v1/players/me/progress") else { return false }

        for _ in 0..<3 {
            let titles = songTitles()
            let remote = ProgressDocument.values(from: document.data)
            let mine = local.snapshot().filter { CloudMerge.isSynced($0.key, songTitles: titles) }
            let result = CloudMerge.merge(local: mine, remote: remote.filter { CloudMerge.isSynced($0.key, songTitles: titles) }, songTitles: titles)
            for (key, value) in result.local { local.set(value, forKey: key) }

            // What this device now has goes up. Keys this build doesn't know stay as the server has them (it merges).
            let outgoing = ProgressDocument.entries(from: local.snapshot(), songTitles: titles)
            do {
                let saved: Document = try await client.put("v1/players/me/progress", body: PutBody(data: outgoing),
                                                           headers: ["If-Match": String(document.revision)])
                document = saved
                notifyChange(if: !result.local.isEmpty)
                return true
            } catch APIError.conflict(let body) {
                guard let current = try? APIClient.makeDecoder().decode(Document.self, from: body) else { return false }
                document = current
            } catch {
                notifyChange(if: !result.local.isEmpty)
                return false
            }
        }
        return false
    }

    private func notifyChange(if changed: Bool) {
        guard changed else { return }
        DispatchQueue.main.async {
            ProgressStore.shared.objectWillChange.send()
            AchievementStore.shared.reload()
        }
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
