//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
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
