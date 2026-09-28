//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

enum LoginMethodScreenViewModelAction: Equatable {
    case password
    case qrCode
}

struct LoginMethodScreenViewState: BindableState {
    let options: LoginOptions
}

enum LoginMethodScreenViewAction {
    case password
    case qrCode
}
