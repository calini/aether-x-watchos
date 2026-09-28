//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum QRLoginScreenViewModelAction {
    case signedIn(ClientProxyProtocol)
}

enum QRLoginScreenStep: Equatable {
    case intro
    case preparing
    case showingQRCode(Data)
    case enteringCheckCode
    case sendingCheckCode
    case waitingForApproval(userCode: String)
    case syncingSecrets
    case failed(QRLoginError)
}

struct QRLoginScreenViewState: BindableState {
    var step: QRLoginScreenStep = .intro
    var bindings = QRLoginScreenBindings()
}

struct QRLoginScreenBindings {
    /// The 2-digit code from the phone, picked with the Digital Crown.
    var checkCode = 0
}

enum QRLoginScreenViewAction {
    case start
    case submitCheckCode
    case retry
    case cancel
}
