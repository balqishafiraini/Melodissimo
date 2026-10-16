//
//  APIClient.swift
//  Melodissimo
//

import Foundation

/// Why a backend call failed. The app always has a fallback (cache, bundled data), so callers mostly just log these.
enum APIError: Error, Equatable {
    /// The backend is switched off or has no real address.
    case notConfigured
    /// A non-2xx answer, with the server's `{ error: { code, message } }` when it sent one.
    case http(status: Int, code: String?, message: String?)
    case transport(String)
    case decoding(String)
}

/// The request headers every call carries (`BACKEND_PLAN.md` §4.1).
struct ClientHeaders: Equatable {
    var platform = "ios"
    var version: String
    /// `CFBundleVersion`, an integer; all comparisons use it.
    var build: Int
    var installId: String
    /// The active content pack's version, 0 for the bundled baseline.
    var contentVersion: Int
    /// The highest content schema this binary understands.
    var schemaVersion: Int
    var languages: [String]
    /// ISO 3166-1 alpha-3 storefront country, empty when unknown.
    var storefront: String

    static let supportedSchemaVersion = 1

    /// The headers for this app, this install and the player's languages.
    static func current(contentVersion: Int = 0, storefront: String = Market.storefront, defaults: UserDefaults = .standard,
                        bundle: Bundle = .main, languages: [String] = Locale.preferredLanguages) -> ClientHeaders {
        ClientHeaders(version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                      build: Int(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0,
                      installId: InstallID.current(defaults: defaults),
                      contentVersion: contentVersion,
                      schemaVersion: supportedSchemaVersion,
                      languages: languages,
                      storefront: storefront)
    }

    var fields: [String: String] {
        var out = [
            "X-App-Platform": platform,
            "X-App-Version": version,
            "X-App-Build": String(build),
            "X-Install-Id": installId,
            "X-Content-Version": String(contentVersion),
            "X-Schema-Version": String(schemaVersion),
        ]
        if !languages.isEmpty { out["Accept-Language"] = languages.joined(separator: ", ") }
        if !storefront.isEmpty { out["X-Storefront"] = storefront }
        return out
    }
}

/// The server's error body: `{ "error": { "code": "...", "message": "..." } }`.
private struct ErrorEnvelope: Decodable {
    struct Inner: Decodable { let code: String?; let message: String? }
    let error: Inner?
}

/// A small `URLSession` wrapper for the backend: standard headers, a timeout per call, typed errors. No third-party code.
struct APIClient {
    let baseURL: URL?
    let session: URLSession
    let headers: () -> ClientHeaders

    init(baseURL: URL? = BackendEnvironment.isEnabled ? BackendEnvironment.apiBaseURL : nil,
         session: URLSession = APIClient.defaultSession,
         headers: @escaping () -> ClientHeaders = { ClientHeaders.current() }) {
        self.baseURL = baseURL
        self.session = session
        self.headers = headers
    }

    /// No waiting for connectivity: an offline player must get the cached data at once, not after a hang.
    static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    /// JSON dates arrive as ISO 8601, with or without fractional seconds.
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = plain.date(from: text) ?? fractional.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad date \(text)"))
        }
        return decoder
    }

    func get<T: Decodable>(_ path: String, timeout: TimeInterval = 8) async throws -> T {
        try await send(path, method: "GET", body: nil, timeout: timeout)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, timeout: TimeInterval = 8) async throws -> T {
        try await send(path, method: "POST", body: try JSONEncoder().encode(body), timeout: timeout)
    }

    private func send<T: Decodable>(_ path: String, method: String, body: Data?, timeout: TimeInterval) async throws -> T {
        guard let baseURL else { throw APIError.notConfigured }
        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: timeout)
        request.httpMethod = method
        for (field, value) in headers().fields { request.setValue(value, forHTTPHeaderField: field) }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport((error as NSError).localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("no HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            throw APIError.http(status: http.statusCode, code: envelope?.error?.code, message: envelope?.error?.message)
        }
        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
