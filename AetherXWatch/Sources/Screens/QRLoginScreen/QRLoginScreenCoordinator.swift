//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class QRLoginScreenCoordinator: CoordinatorProtocol {
    private let viewModel: QRLoginScreenViewModel

    var actionsPublisher: AnyPublisher<QRLoginScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    var context: QRLoginScreenViewModel.Context {
        viewModel.context
    }

    init(qrLoginService: QRLoginServiceProtocol) {
        viewModel = QRLoginScreenViewModel(qrLoginService: qrLoginService)
    }

    func toPresentable() -> AnyView {
        AnyView(QRLoginScreen(context: viewModel.context))
    }
}
