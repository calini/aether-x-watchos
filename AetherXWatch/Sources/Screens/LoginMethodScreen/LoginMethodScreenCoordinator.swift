//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class LoginMethodScreenCoordinator: CoordinatorProtocol {
    private let viewModel: LoginMethodScreenViewModel

    var actionsPublisher: AnyPublisher<LoginMethodScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    var context: LoginMethodScreenViewModel.Context {
        viewModel.context
    }

    init(options: LoginOptions) {
        viewModel = LoginMethodScreenViewModel(options: options)
    }

    func toPresentable() -> AnyView {
        AnyView(LoginMethodScreen(context: viewModel.context))
    }
}
