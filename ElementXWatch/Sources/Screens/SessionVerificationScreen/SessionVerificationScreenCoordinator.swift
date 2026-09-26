//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class SessionVerificationScreenCoordinator: CoordinatorProtocol {
    private let viewModel: SessionVerificationScreenViewModel

    var actionsPublisher: AnyPublisher<SessionVerificationScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    init(controllerProxy: SessionVerificationControllerProxyProtocol?) {
        viewModel = SessionVerificationScreenViewModel(controllerProxy: controllerProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(SessionVerificationScreen(context: viewModel.context))
    }
}
