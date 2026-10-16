//
//  UpdateGate.swift
//  Melodissimo
//

import Foundation

/// When the update and maintenance screens may appear (`BACKEND_PLAN.md` §4.4, §5.1, B5.4).
enum UpdateGate {
    /// A soft prompt shows at most once per `recommendedBuild` per three days.
    static let softInterval: TimeInterval = 3 * 24 * 3600

    static func softKey(recommendedBuild: Int) -> String { "backend_softUpdateShown_\(recommendedBuild)" }

    static func shouldShowSoft(lastShown: Date?, now: Date) -> Bool {
        guard let lastShown else { return true }
        return now.timeIntervalSince(lastShown) >= softInterval
    }

    /// The blocking screen never interrupts a song: during play it waits and appears when the play screen closes.
    static func showsBlockingScreen(directive: UpdateDirective, isPlaying: Bool) -> Bool {
        directive == .hard && !isPlaying
    }

    /// Maintenance takes over the screen only when it blocks play, and never during a song.
    static func showsMaintenanceScreen(_ info: Bootstrap.MaintenanceInfo?, isPlaying: Bool) -> Bool {
        info?.blocksPlay == true && !isPlaying
    }

    /// The App Store link, only when it is a real http(s) URL.
    static func storeURL(_ text: String?) -> URL? {
        BackendEnvironment.parseBaseURL(text)
    }
}
