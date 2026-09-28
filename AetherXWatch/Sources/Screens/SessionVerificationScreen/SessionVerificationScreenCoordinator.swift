//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class SessionVerificationScreenCoordinator: CoordinatorProtocol {
    private let viewModel: SessionVerificationScreenViewModel

    var actionsPublisher: AnyPublisher<SessionVerificationScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    /// Test hook, and lets the flow cancel an in-progress verification when the sheet is swiped away.
    var context: SessionVerificationScreenViewModel.Context {
        viewModel.context
    }

    init(controllerLoader: @escaping () async -> SessionVerificationControllerProxyProtocol?) {
        viewModel = SessionVerificationScreenViewModel(controllerLoader: controllerLoader)
    }

    func toPresentable() -> AnyView {
        AnyView(SessionVerificationScreen(context: viewModel.context))
    }
}
