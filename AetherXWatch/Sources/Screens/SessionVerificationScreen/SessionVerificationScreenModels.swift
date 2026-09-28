//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
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

    /// Whether the flow is still running, i.e. not idle and not already at a terminal step.
    var isFlowActive: Bool {
        switch step {
        case .intro, .verified, .declined, .cancelled, .failed:
            false
        case .waitingForAcceptance, .startingSas, .comparing, .confirming:
            true
        }
    }
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
