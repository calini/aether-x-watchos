//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// Sets up Rust SDK logging: system log plus rolling files in Caches/Logs (retrievable from Xcode's Devices window).
enum Tracing {
    static func setUp() {
        let directory = URL.logsDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        #if DEBUG
        let level = LogLevel.debug
        #else
        let level = LogLevel.info
        #endif

        do {
            try initPlatform(config: .init(logLevel: level,
                                           traceLogPacks: [],
                                           extraTargets: [],
                                           writeToStdoutOrSystem: true,
                                           writeToFiles: .init(path: directory.path(percentEncoded: false),
                                                               filePrefix: "rust",
                                                               fileSuffix: "log",
                                                               maxTotalSizeBytes: 20_000_000,
                                                               maxAgeSeconds: 3 * 24 * 60 * 60)),
                             useLightweightTokioRuntime: true)
        } catch {
            MXLog.error("Failed to set up Rust tracing: \(error)")
        }
    }
}
