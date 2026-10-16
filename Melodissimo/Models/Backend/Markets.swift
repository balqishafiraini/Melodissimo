//
//  Markets.swift
//  Melodissimo
//
//  Country targeting for songs, packs, shop items and products (`BACKEND_PLAN.md` §4.10). Pure and shared in spirit with the
//  server's `domain/markets.ts`.
//

import Foundation

extension Markets {

    /// Whether an item with these markets is offered in a country.
    ///
    /// - No `markets`, or an empty `include`: worldwide, except where `exclude` names the country.
    /// - `country` is the App Store storefront (ISO 3166-1 alpha-3). When it is unknown, the device's region
    ///   (`deviceCountry`) stands in for items that name countries; worldwide items always show.
    /// - `isOwned`: what a player has is never taken away, in any country.
    static func allows(_ markets: Markets?, storefront: String?, deviceCountry: String?, isOwned: Bool = false) -> Bool {
        if isOwned { return true }
        guard let markets else { return true }
        let include = markets.include ?? []
        let exclude = markets.exclude ?? []
        let country = (storefront?.isEmpty == false ? storefront : deviceCountry)?.uppercased()
        if let country, exclude.contains(country) { return false }
        if include.isEmpty { return true }
        guard let country else { return false }
        return include.contains(country)
    }

    /// Whether an item is featured in a country (shown first, with a badge). It never changes availability.
    static func isFeatured(_ markets: Markets?, storefront: String?, deviceCountry: String?) -> Bool {
        guard let featured = markets?.featuredIn, !featured.isEmpty else { return false }
        let country = (storefront?.isEmpty == false ? storefront : deviceCountry)?.uppercased()
        return country.map(featured.contains) ?? false
    }

    /// Items featured in this country first, the rest after them, each group in its original order.
    static func featuredFirst<T>(_ items: [T], markets: (T) -> Markets?, storefront: String?, deviceCountry: String?) -> [T] {
        let featured = items.filter { isFeatured(markets($0), storefront: storefront, deviceCountry: deviceCountry) }
        let rest = items.filter { !isFeatured(markets($0), storefront: storefront, deviceCountry: deviceCountry) }
        return featured + rest
    }
}

/// The player's country: the App Store storefront when StoreKit has told us, else the device region.
enum Market {
    private static let storefrontKey = "backend_storefront"

    /// The storefront country (alpha-3) last reported by StoreKit, kept so the first request of a launch can send it.
    static var storefront: String {
        get { UserDefaults.standard.string(forKey: storefrontKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: storefrontKey) }
    }

    /// The device region as alpha-3, or `nil` when unknown or not in the table.
    static var deviceCountry: String? { alpha3(forRegion: Locale.current.region?.identifier) }

    static func alpha3(forRegion alpha2: String?) -> String? {
        guard let alpha2 else { return nil }
        return alpha3Table[alpha2.uppercased()]
    }

    /// ISO 3166-1 alpha-2 → alpha-3 for the places the app is likely to be sold.
    private static let alpha3Table: [String: String] = [
        "ID": "IDN", "MY": "MYS", "SG": "SGP", "BN": "BRN", "TH": "THA", "PH": "PHL", "VN": "VNM", "KH": "KHM", "LA": "LAO",
        "MM": "MMR", "TL": "TLS", "JP": "JPN", "KR": "KOR", "CN": "CHN", "TW": "TWN", "HK": "HKG", "IN": "IND", "PK": "PAK",
        "BD": "BGD", "LK": "LKA", "AU": "AUS", "NZ": "NZL", "US": "USA", "CA": "CAN", "MX": "MEX", "BR": "BRA", "AR": "ARG",
        "CL": "CHL", "CO": "COL", "PE": "PER", "GB": "GBR", "IE": "IRL", "DE": "DEU", "FR": "FRA", "ES": "ESP", "PT": "PRT",
        "IT": "ITA", "NL": "NLD", "BE": "BEL", "CH": "CHE", "AT": "AUT", "SE": "SWE", "NO": "NOR", "DK": "DNK", "FI": "FIN",
        "PL": "POL", "CZ": "CZE", "GR": "GRC", "TR": "TUR", "RU": "RUS", "UA": "UKR", "SA": "SAU", "AE": "ARE", "QA": "QAT",
        "EG": "EGY", "ZA": "ZAF", "NG": "NGA", "KE": "KEN", "IL": "ISR",
    ]
}
