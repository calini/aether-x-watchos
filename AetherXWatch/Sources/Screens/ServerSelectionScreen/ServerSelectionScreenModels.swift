//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum ServerSelectionScreenViewModelAction {
    case configured(LoginOptions)
}

struct ServerSelectionScreenViewState: BindableState {
    var isLoading = false
    /// The input that failed, so editing the field hides the error.
    var failedServer: String?
    var failureMessage: String?
    var bindings = ServerSelectionScreenBindings()

    var trimmedServer: String {
        bindings.server.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canContinue: Bool {
        !isLoading && !trimmedServer.isEmpty
    }

    var errorMessage: String? {
        failedServer == bindings.server ? failureMessage : nil
    }
}

struct ServerSelectionScreenBindings {
    var server = WatchAppSettings.defaultServerName
}

enum ServerSelectionScreenViewAction {
    case `continue`
}
