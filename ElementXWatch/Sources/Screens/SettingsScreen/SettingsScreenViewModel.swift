//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

typealias SettingsScreenViewModelType = StateStoreViewModelV2<SettingsScreenViewState, SettingsScreenViewAction>

final class SettingsScreenViewModel: SettingsScreenViewModelType, SettingsScreenViewModelProtocol {
    private let actionsSubject = PassthroughSubject<SettingsScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<SettingsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol) {
        super.init(initialViewState: SettingsScreenViewState(userID: clientProxy.userID))

        clientProxy.verificationStatePublisher
            .sink { [weak self] verification in self?.state.verification = verification }
            .store(in: &cancellables)

        Task { [weak self] in
            let displayName = await clientProxy.loadDisplayName()
            self?.state.displayName = displayName
        }
    }

    override func process(viewAction: SettingsScreenViewAction) {
        switch viewAction {
        case .verifySession:
            actionsSubject.send(.verifySession)
        case .signOut:
            state.bindings.isConfirmingSignOut = true
        case .confirmSignOut:
            state.bindings.isConfirmingSignOut = false
            actionsSubject.send(.signOut)
        }
    }
}
