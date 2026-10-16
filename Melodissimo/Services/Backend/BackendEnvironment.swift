//
//  BackendEnvironment.swift
//  Melodissimo
//
//  Where the app's own backend lives and whether it may be called at all. Separate from `OnlineServices`
//  (Game Center and iCloud).
//
//  Info.plist keys (filled from the build settings `MELODISSIMO_API_BASE` / `MELODISSIMO_CDN_BASE` / `MELODISSIMO_ENV`,
//  Debug → DEV (backend staging), Release → PROD (backend production)): `MelodissimoAPIBaseURL`, `MelodissimoCDNBaseURL`,
//  `MelodissimoEnvironment`, `MelodissimoBackendEnabled` (default YES).
//  Debug builds also read the launch arguments `-apiBase <url>` and `-qaBackend NO`, so the QA scripts in
//  `Scripts/iphone/` run offline and deterministic.
//

import Foundation

enum BackendEnvironment {

    /// A base URL from a setting, or `nil` when it is empty, not a URL, or still has an unexpanded `$(…)` placeholder.
    static func parseBaseURL(_ value: Any?) -> URL? {
        guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, !text.contains("$("),
              let url = URL(string: text), let scheme = url.scheme, ["http", "https"].contains(scheme), url.host != nil else { return nil }
        return url
    }

    /// Hosts under `.invalid` are placeholders for a domain that is not chosen yet; they are never contacted.
    static func isPlaceholder(_ url: URL) -> Bool {
        (url.host ?? "").hasSuffix(".invalid")
    }

    static var apiBaseURL: URL? {
        #if DEBUG
        if let override = parseBaseURL(UserDefaults.standard.string(forKey: "apiBase")) { return override }
        #endif
        return parseBaseURL(Bundle.main.object(forInfoDictionaryKey: "MelodissimoAPIBaseURL"))
    }

    static var cdnBaseURL: URL? {
        parseBaseURL(Bundle.main.object(forInfoDictionaryKey: "MelodissimoCDNBaseURL"))
    }

    /// `DEV` (Debug, backend staging) or `PROD` (Release, backend production). Anything unexpected counts as `PROD`.
    static var name: String {
        parseName(Bundle.main.object(forInfoDictionaryKey: "MelodissimoEnvironment"))
    }

    static func parseName(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DEV" ? "DEV" : "PROD"
    }

    static var isDev: Bool { name == "DEV" }

    /// Whether the app talks to the backend: switched on in Info.plist (default yes), not turned off with `-qaBackend NO`,
    /// and pointing at a real address.
    static var isEnabled: Bool {
        #if DEBUG
        if UserDefaults.standard.object(forKey: "qaBackend") != nil, !UserDefaults.standard.bool(forKey: "qaBackend") {
            return false
        }
        #endif
        guard Bundle.main.object(forInfoDictionaryKey: "MelodissimoBackendEnabled") as? Bool ?? true else { return false }
        guard let url = apiBaseURL else { return false }
        return !isPlaceholder(url)
    }
}
