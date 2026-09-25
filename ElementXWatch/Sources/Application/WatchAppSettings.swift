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
    static let keychainService = "io.ilie.elementx.watch.sessions"
    static let userAgent = "ElementXWatch/0.1.0 (watchOS)"

    /// OAuth client metadata for dynamic registration with the account's MAS.
    /// All URIs share one host, as MAS requires; the redirect is never used by the device-code QR flow.
    static var oAuthConfiguration: OAuthConfiguration {
        OAuthConfiguration(clientName: "Element X Watch",
                           redirectUri: "https://ilie.io/element-x-watch/oauth",
                           clientUri: "https://ilie.io/element-x-watch",
                           logoUri: "https://ilie.io/element-x-watch/logo.png",
                           tosUri: "https://ilie.io/element-x-watch/terms",
                           policyUri: "https://ilie.io/element-x-watch/privacy",
                           staticRegistrations: [:])
    }
}
