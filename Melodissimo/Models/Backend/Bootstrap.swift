//
//  Bootstrap.swift
//  Melodissimo
//
//  The response of `GET /v1/bootstrap` (`BACKEND_PLAN.md` §4.2, `contracts/schema/bootstrap.schema.json`). Everything is
//  optional except `serverTime` and `ttlSeconds`, unknown fields are ignored, and unknown enum values decode to `.unknown`.
//

import Foundation

/// A JSON value of any shape, for `tuning` values and other open-ended fields.
enum JSONValue: Codable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

struct Bootstrap: Codable, Equatable {
    var serverTime: Date
    var ttlSeconds: Int
    var update: UpdateInfo?
    var maintenance: MaintenanceInfo?
    var flags: [String: Bool]?
    var tuning: [String: JSONValue]?
    var content: ContentInfo?
    var announcements: [Announcement]?

    struct UpdateInfo: Codable, Equatable {
        /// What the server decided for this client. The app recomputes it from `policy`, so a hard block works offline.
        var action: Action
        var policy: UpdatePolicy?
        var storeUrl: String?
        var title: LocalizedText?
        var message: LocalizedText?
    }

    enum Action: String, Codable, Equatable {
        case none, soft, hard
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Action(rawValue: raw) ?? .unknown
        }
    }

    struct UpdatePolicy: Codable, Equatable {
        var minSupportedBuild: Int
        var recommendedBuild: Int
        var blockedBuilds: [Int]

        init(minSupportedBuild: Int, recommendedBuild: Int, blockedBuilds: [Int] = []) {
            self.minSupportedBuild = minSupportedBuild
            self.recommendedBuild = recommendedBuild
            self.blockedBuilds = blockedBuilds
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            minSupportedBuild = try c.decode(Int.self, forKey: .minSupportedBuild)
            recommendedBuild = try c.decode(Int.self, forKey: .recommendedBuild)
            blockedBuilds = try c.decodeIfPresent([Int].self, forKey: .blockedBuilds) ?? []
        }
    }

    struct MaintenanceInfo: Codable, Equatable {
        var title: LocalizedText?
        var message: LocalizedText?
        var until: String?
        var blocksPlay: Bool?
    }

    struct ContentInfo: Codable, Equatable {
        var version: Int
        var schemaVersion: Int
        var manifestUrl: String
        var signatureUrl: String
        var sha256: String
    }

    struct Announcement: Codable, Equatable, Identifiable {
        var id: String
        var startsAt: String
        var endsAt: String
        var kind: String
        var title: LocalizedText?
        var body: LocalizedText?
        var imageUrl: String?
        var route: String?
    }
}
