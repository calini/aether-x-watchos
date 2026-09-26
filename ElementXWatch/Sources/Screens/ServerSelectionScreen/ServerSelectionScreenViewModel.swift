//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

typealias ServerSelectionScreenViewModelType = StateStoreViewModelV2<ServerSelectionScreenViewState, ServerSelectionScreenViewAction>

final class ServerSelectionScreenViewModel: ServerSelectionScreenViewModelType, ServerSelectionScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let actionsSubject = PassthroughSubject<ServerSelectionScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<ServerSelectionScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: AuthenticationServiceProtocol) {
        self.authenticationService = authenticationService
        super.init(initialViewState: ServerSelectionScreenViewState())
    }

    override func process(viewAction: ServerSelectionScreenViewAction) {
        switch viewAction {
        case .continue:
            configure()
        }
    }

    private func configure() {
        guard state.canContinue else { return }
        let input = state.bindings.server
        state.isLoading = true

        Task {
            let result = await authenticationService.configure(server: state.trimmedServer)
            state.isLoading = false
            switch result {
            case .success(let options):
                actionsSubject.send(.configured(options))
            case .failure(let error):
                state.failedServer = input
                state.failureMessage = error.message
            }
        }
    }
}
