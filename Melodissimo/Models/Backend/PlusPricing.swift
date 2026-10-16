//
//  PlusPricing.swift
//  Melodissimo
//

import Foundation

/// Arithmetic for the Plus paywall. Prices themselves come only from the store (`BACKEND_PLAN.md` §3.4 #6); this only
/// compares two of them.
enum PlusPricing {

    /// How much cheaper the yearly plan is than twelve monthly payments, as a whole percent. `nil` when the yearly plan
    /// isn't cheaper (or a price is missing or zero), so the paywall never claims a saving that isn't there.
    static func yearlySavingPercent(monthly: Decimal?, yearly: Decimal?) -> Int? {
        guard let monthly, let yearly, monthly > 0, yearly > 0 else { return nil }
        let twelve = monthly * 12
        guard yearly < twelve else { return nil }
        let saving = (twelve - yearly) / twelve * 100
        return NSDecimalNumber(decimal: saving).rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false)).intValue
    }

    /// "7 days free" from an introductory offer's period, in the player's language.
    static func trialText(value: Int, unit: Calendar.Component) -> String {
        switch unit {
        case .day: return value == 1 ? NSLocalizedString("1 day free", comment: "") : String(format: NSLocalizedString("%lld days free", comment: ""), value)
        case .weekOfYear: return trialText(value: value * 7, unit: .day)
        case .month: return value == 1 ? NSLocalizedString("1 month free", comment: "") : String(format: NSLocalizedString("%lld months free", comment: ""), value)
        default: return NSLocalizedString("Free trial", comment: "")
        }
    }
}

/// Where the Terms of Use and Privacy Policy live. App Review requires both on a subscription screen. They come from the
/// Info.plist keys `MelodissimoTermsURL` / `MelodissimoPrivacyURL` (build settings `MELODISSIMO_TERMS_URL` / `…PRIVACY_URL`).
enum LegalLinks {
    static var terms: URL? { url("MelodissimoTermsURL") }
    static var privacy: URL? { url("MelodissimoPrivacyURL") }

    private static func url(_ key: String) -> URL? {
        guard let url = BackendEnvironment.parseBaseURL(Bundle.main.object(forInfoDictionaryKey: key)), !BackendEnvironment.isPlaceholder(url) else { return nil }
        return url
    }
}
