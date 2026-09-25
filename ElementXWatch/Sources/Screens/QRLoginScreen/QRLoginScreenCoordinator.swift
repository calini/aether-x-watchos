//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class QRLoginScreenCoordinator: CoordinatorProtocol {
    private let viewModel: QRLoginScreenViewModel

    var actionsPublisher: AnyPublisher<QRLoginScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    init(qrLoginService: QRLoginServiceProtocol) {
        viewModel = QRLoginScreenViewModel(qrLoginService: qrLoginService)
    }

    func toPresentable() -> AnyView {
        AnyView(QRLoginScreen(context: viewModel.context))
    }
}
