//
//  Analytics.swift
//  Melodissimo
//
//  First-party, privacy-safe usage events (`BACKEND_PLAN.md` Task B9). They go to our own backend only: no third-party SDK,
//  no IDFA/IDFV, no names or e-mails. The only identifier is the random install id; props stay coarse (song id, stars, mode).
//  Nothing is collected unless the server switches the `analytics` flag on, and only for the share of installs that
//  `analytics.sampleRate` selects.
//

import Foundation
import UIKit

/// The event names the server accepts (`events.schema.json`).
enum AnalyticsEvent: String, CaseIterable {
    case appOpen = "app_open"
    case stageStart = "stage_start"
    case stageEnd = "stage_end"
    case songPerformEnd = "song_perform_end"
    case shopBuyCoins = "shop_buy_coins"
    case paywallView = "paywall_view"
    case purchaseSuccess = "purchase_success"
    case purchasePending = "purchase_pending"
    case reviveUsed = "revive_used"
    case coinsPurchased = "coins_purchased"
    case shopItemBought = "shop_item_bought"
    case contentActivated = "content_activated"
    case contentVerifyFailed = "content_verify_failed"
    case updatePromptShown = "update_prompt_shown"
}

struct BufferedEvent: Codable, Equatable, Sendable {
    var name: String
    var at: Date
    var props: [String: JSONValue]
}

final class Analytics: @unchecked Sendable {

    static let shared = Analytics()

    /// Events are sent when this many are waiting, and whenever the app goes to the background.
    static let flushThreshold = 20
    static let batchSize = 50
    /// The buffer never grows past this, so a long offline stretch can't fill the disk.
    static let maxBuffered = 500

    private let fileURL: URL
    private let makeClient: () -> APIClient
    private let isEnabled: () -> Bool
    private let installId: () -> String
    private let now: () -> Date
    private let queue = DispatchQueue(label: "melodissimo.analytics")
    private var buffer: [BufferedEvent]
    private var isFlushing = false
    private var observer: NSObjectProtocol?

    init(fileURL: URL = Analytics.defaultFileURL,
         makeClient: @escaping () -> APIClient = { APIClient() },
         isEnabled: @escaping () -> Bool = Analytics.defaultIsEnabled,
         installId: @escaping () -> String = { InstallID.current() },
         now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.makeClient = makeClient
        self.isEnabled = isEnabled
        self.installId = installId
        self.now = now
        buffer = Self.readBuffer(fileURL)
    }

    static var defaultFileURL: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Backend/events.json")
    }

    /// The backend is on, the `analytics` flag is on, and this install is inside the sample.
    static func defaultIsEnabled() -> Bool {
        guard BackendEnvironment.isEnabled, FeatureFlags.isOn(.analytics) else { return false }
        let rate = Tuning.int("analytics.sampleRate", default: 100, range: 0...100)
        return RolloutBucket.bucket(installId: InstallID.current(), key: "analytics") < rate
    }

    /// Flushes whenever the app goes to the background. Call once at launch.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.flush()
        }
    }

    // MARK: Logging

    /// Records an event. Does nothing when analytics is off. Props must be coarse (a song id, a mode, a star count).
    func log(_ event: AnalyticsEvent, props: [String: JSONValue] = [:]) {
        guard isEnabled() else { return }
        let entry = BufferedEvent(name: event.rawValue, at: now(), props: props)
        queue.async { [self] in
            buffer.append(entry)
            if buffer.count > Self.maxBuffered { buffer.removeFirst(buffer.count - Self.maxBuffered) }
            save()
            if buffer.count >= Self.flushThreshold { flushLocked() }
        }
    }

    static func log(_ event: AnalyticsEvent, props: [String: JSONValue] = [:]) {
        shared.log(event, props: props)
    }

    /// Sends what is buffered, in batches of at most 50. Events stay buffered if a batch fails.
    func flush() {
        queue.async { [self] in flushLocked() }
    }

    /// Waits for everything queued so far (tests).
    func waitUntilIdle() {
        queue.sync {}
    }

    var bufferedCount: Int { queue.sync { buffer.count } }

    private struct Batch: Encodable {
        struct Item: Encodable { let name: String; let at: String; let props: [String: JSONValue] }
        let events: [Item]
    }
    private struct Accepted: Decodable { let accepted: Int? }

    private func flushLocked() {
        guard isEnabled(), !isFlushing, !buffer.isEmpty else { return }
        isFlushing = true
        let batch = Array(buffer.prefix(Self.batchSize))
        let formatter = ISO8601DateFormatter()
        let body = Batch(events: batch.map { Batch.Item(name: $0.name, at: formatter.string(from: $0.at), props: $0.props) })
        let client = makeClient()
        Task { [self] in
            let sent = (try? await client.post("v1/events", body: body, timeout: 8) as Accepted) != nil
            queue.async { [self] in
                if sent {
                    buffer.removeFirst(min(batch.count, buffer.count))
                    save()
                }
                isFlushing = false
                // More waiting? Keep going until the buffer is empty or a batch fails.
                if sent, buffer.count >= Self.flushThreshold { flushLocked() }
            }
        }
    }

    // MARK: Disk

    private static func readBuffer(_ url: URL) -> [BufferedEvent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([BufferedEvent].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(buffer).write(to: fileURL, options: .atomic)
        } catch {
            // Analytics must never break the app.
        }
    }
}
