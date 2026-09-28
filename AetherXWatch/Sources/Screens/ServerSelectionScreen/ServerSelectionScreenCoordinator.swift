//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class ServerSelectionScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ServerSelectionScreenViewModel

    var actionsPublisher: AnyPublisher<ServerSelectionScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    var context: ServerSelectionScreenViewModel.Context {
        viewModel.context
    }

    init(authenticationService: AuthenticationServiceProtocol) {
        viewModel = ServerSelectionScreenViewModel(authenticationService: authenticationService)
    }

    func toPresentable() -> AnyView {
        AnyView(ServerSelectionScreen(context: viewModel.context))
    }
}
