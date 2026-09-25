//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

enum SettingsScreenViewModelAction {
    case signOut
}

struct SettingsScreenViewState: BindableState {
    let userID: String
    var displayName: String?
    var verification: SessionVerification = .unknown
    var bindings = SettingsScreenBindings()
}

struct SettingsScreenBindings {
    var isConfirmingSignOut = false
}

enum SettingsScreenViewAction {
    case signOut
    case confirmSignOut
}
