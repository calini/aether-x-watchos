//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

typealias LoginMethodScreenViewModelType = StateStoreViewModelV2<LoginMethodScreenViewState, LoginMethodScreenViewAction>

final class LoginMethodScreenViewModel: LoginMethodScreenViewModelType, LoginMethodScreenViewModelProtocol {
    private let actionsSubject = PassthroughSubject<LoginMethodScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<LoginMethodScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(options: LoginOptions) {
        super.init(initialViewState: LoginMethodScreenViewState(options: options))
    }

    override func process(viewAction: LoginMethodScreenViewAction) {
        switch viewAction {
        case .password where state.options.supportsPassword:
            actionsSubject.send(.password)
        case .qrCode where state.options.supportsQRCode:
            actionsSubject.send(.qrCode)
        default:
            break
        }
    }
}
