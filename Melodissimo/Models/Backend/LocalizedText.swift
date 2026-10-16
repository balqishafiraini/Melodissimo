//
//  LocalizedText.swift
//  Melodissimo
//

import Foundation

/// A text in several languages: BCP-47 language code to string (`BACKEND_PLAN.md` §4.10). `en` is expected;
/// any other language may appear without a code change.
struct LocalizedText: Codable, Hashable {
    let values: [String: String]

    init(_ values: [String: String]) {
        self.values = values
    }

    /// A text that reads the same in every language.
    init(_ text: String) {
        values = ["en": text]
    }

    init(from decoder: Decoder) throws {
        values = try decoder.singleValueContainer().decode([String: String].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    /// Picks the text for the first preferred language that has one: the exact code (`pt-BR`), then the code
    /// with trailing parts dropped (`pt`), then `en`, then any value (the first by language code).
    func resolved(preferred: [String] = Locale.preferredLanguages) -> String {
        for language in preferred {
            var parts = language.replacingOccurrences(of: "_", with: "-").split(separator: "-").map(String.init)
            while !parts.isEmpty {
                if let text = values[parts.joined(separator: "-")] { return text }
                parts.removeLast()
            }
        }
        return values["en"] ?? values.sorted { $0.key < $1.key }.first?.value ?? ""
    }
}
