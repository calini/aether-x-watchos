//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

enum SettingsScreenViewModelAction {
    case verifySession
    case signOut
}

struct SettingsScreenViewState: BindableState {
    let userID: String
    var displayName: String?
    var verification: SessionVerification = .unknown
    var audioSupport: AudioSupport = .unchecked
    var bindings = SettingsScreenBindings()

    var canVerify: Bool {
        verification == .unverified
    }
}

/// Whether watchOS can encode and decode Opus, for the DEBUG device check.
enum AudioSupport {
    case unchecked
    case checking
    case supported
    case unsupported
}

struct SettingsScreenBindings {
    var isConfirmingSignOut = false
}

enum SettingsScreenViewAction {
    case verifySession
    case signOut
    case confirmSignOut
    case checkAudioSupport
}
