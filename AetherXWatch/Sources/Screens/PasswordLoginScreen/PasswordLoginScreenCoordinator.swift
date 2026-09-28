//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class PasswordLoginScreenCoordinator: CoordinatorProtocol {
    private let viewModel: PasswordLoginScreenViewModel

    var actionsPublisher: AnyPublisher<PasswordLoginScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    var context: PasswordLoginScreenViewModel.Context {
        viewModel.context
    }

    init(serverName: String, authenticationService: AuthenticationServiceProtocol) {
        viewModel = PasswordLoginScreenViewModel(serverName: serverName, authenticationService: authenticationService)
    }

    func toPresentable() -> AnyView {
        AnyView(PasswordLoginScreen(context: viewModel.context))
    }
}
