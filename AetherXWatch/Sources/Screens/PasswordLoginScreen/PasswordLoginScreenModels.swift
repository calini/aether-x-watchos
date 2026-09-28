//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum PasswordLoginScreenViewModelAction {
    case signedIn(ClientProxyProtocol)
}

struct PasswordLoginScreenViewState: BindableState {
    let serverName: String
    var isLoading = false
    var errorMessage: String?
    var bindings = PasswordLoginScreenBindings()

    var canSignIn: Bool {
        !isLoading && !bindings.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !bindings.password.isEmpty
    }
}

struct PasswordLoginScreenBindings {
    var username = ""
    var password = ""
}

enum PasswordLoginScreenViewAction {
    case signIn
}
