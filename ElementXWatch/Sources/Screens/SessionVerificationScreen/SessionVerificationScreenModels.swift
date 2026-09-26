//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

enum SessionVerificationStep: Equatable {
    case intro
    case waitingForAcceptance
    case startingSas
    case comparing(VerificationData)
    case confirming
    case verified
    case declined
    case cancelled
    case failed
}

struct SessionVerificationScreenViewState: BindableState {
    var step: SessionVerificationStep = .intro
}

enum SessionVerificationScreenViewAction {
    case start
    case match
    case noMatch
    case cancel
    case tryAgain
    case dismiss
}

enum SessionVerificationScreenViewModelAction {
    case dismiss
}
