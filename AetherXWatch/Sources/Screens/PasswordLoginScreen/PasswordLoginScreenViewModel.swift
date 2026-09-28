//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine

typealias PasswordLoginScreenViewModelType = StateStoreViewModelV2<PasswordLoginScreenViewState, PasswordLoginScreenViewAction>

final class PasswordLoginScreenViewModel: PasswordLoginScreenViewModelType, PasswordLoginScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let actionsSubject = PassthroughSubject<PasswordLoginScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<PasswordLoginScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(serverName: String, authenticationService: AuthenticationServiceProtocol) {
        self.authenticationService = authenticationService
        super.init(initialViewState: PasswordLoginScreenViewState(serverName: serverName))
    }

    override func process(viewAction: PasswordLoginScreenViewAction) {
        switch viewAction {
        case .signIn:
            signIn()
        }
    }

    private func signIn() {
        guard state.canSignIn else { return }
        let username = state.bindings.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = state.bindings.password
        state.isLoading = true
        state.errorMessage = nil

        Task {
            let result = await authenticationService.login(username: username, password: password)
            state.isLoading = false
            state.bindings.password = ""
            switch result {
            case .success(let clientProxy):
                actionsSubject.send(.signedIn(clientProxy))
            case .failure(let error):
                state.errorMessage = error.message
            }
        }
    }
}
