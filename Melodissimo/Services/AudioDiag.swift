//
//  AudioDiag.swift
//  Melodissimo
//

import Foundation
#if DEBUG
import os
#endif

/// Audio diagnostics for the Debug build: one `os_log` line per engine start, session activation, interruption,
/// route change and similar event, so a device log shows what the audio stack did around a glitch.
///
/// Read them with `xcrun simctl spawn <udid> log stream --predicate 'subsystem == "melodissimo.audio"'`, or in the
/// Xcode console. In Release the call is a no-op and the message is never built (it is an autoclosure).
enum AudioDiag {
    #if DEBUG
    private static let logger = Logger(subsystem: "melodissimo.audio", category: "audio")
    #endif

    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        logger.notice("\(text, privacy: .public)")
        #endif
    }
}
