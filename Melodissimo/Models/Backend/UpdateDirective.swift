//
//  UpdateDirective.swift
//  Melodissimo
//

import Foundation

/// What the update policy asks of this build (`BACKEND_PLAN.md` §4.4). The same rules run on the server
/// (`updatePolicy.ts`) with the same test vectors, so a hard block also works offline from the cached policy.
enum UpdateDirective: String, Equatable {
    case none, soft, hard

    static func decide(build: Int, policy: Bootstrap.UpdatePolicy) -> UpdateDirective {
        if policy.blockedBuilds.contains(build) { return .hard }
        if build < policy.minSupportedBuild { return .hard }
        if build < policy.recommendedBuild { return .soft }
        return .none
    }
}
