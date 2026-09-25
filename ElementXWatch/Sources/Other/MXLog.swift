//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import OSLog

/// App-wide logging. Never pass secrets, tokens or message content.
nonisolated enum MXLog {
    private static let logger = Logger(subsystem: "io.ilie.elementx.watch", category: "app")

    static func verbose(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let text = message()
        logger.debug("[\(file, privacy: .public):\(line, privacy: .public)] \(text, privacy: .public)")
    }

    static func info(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let text = message()
        logger.info("[\(file, privacy: .public):\(line, privacy: .public)] \(text, privacy: .public)")
    }

    static func warning(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let text = message()
        logger.warning("[\(file, privacy: .public):\(line, privacy: .public)] \(text, privacy: .public)")
    }

    static func error(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let text = message()
        logger.error("[\(file, privacy: .public):\(line, privacy: .public)] \(text, privacy: .public)")
    }
}
