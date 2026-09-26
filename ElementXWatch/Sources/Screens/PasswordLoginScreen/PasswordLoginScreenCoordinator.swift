//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class PasswordLoginScreenCoordinator: CoordinatorProtocol {
    private let viewModel: PasswordLoginScreenViewModel

    var actionsPublisher: AnyPublisher<PasswordLoginScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    init(serverName: String, authenticationService: AuthenticationServiceProtocol) {
        viewModel = PasswordLoginScreenViewModel(serverName: serverName, authenticationService: authenticationService)
    }

    func toPresentable() -> AnyView {
        AnyView(PasswordLoginScreen(context: viewModel.context))
    }
}
