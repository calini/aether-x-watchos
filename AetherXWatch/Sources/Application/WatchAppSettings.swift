//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// Static configuration for the watch app.
nonisolated enum WatchAppSettings {
    static let defaultServerName = "matrix.org"
    static let keychainService = "io.ilie.aetherx.watch.sessions"
    static let userAgent = "AetherXWatch/0.1.0 (watchOS)"

    /// OAuth client metadata for dynamic registration with the account's MAS.
    /// All URIs share one host, as MAS requires; the redirect is never used by the device-code QR flow.
    static var oAuthConfiguration: OAuthConfiguration {
        OAuthConfiguration(clientName: "Aether X Watch",
                           redirectUri: "https://ilie.io/aether-x-watch/oauth",
                           clientUri: "https://ilie.io/aether-x-watch",
                           logoUri: "https://ilie.io/aether-x-watch/logo.png",
                           tosUri: "https://ilie.io/aether-x-watch/terms",
                           policyUri: "https://ilie.io/aether-x-watch/privacy",
                           staticRegistrations: [:])
    }
}
