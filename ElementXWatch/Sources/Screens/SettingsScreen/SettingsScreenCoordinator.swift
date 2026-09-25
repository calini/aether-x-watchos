//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class SettingsScreenCoordinator: CoordinatorProtocol {
    private let viewModel: SettingsScreenViewModel

    var actionsPublisher: AnyPublisher<SettingsScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    init(clientProxy: ClientProxyProtocol) {
        viewModel = SettingsScreenViewModel(clientProxy: clientProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(SettingsScreen(context: viewModel.context))
    }
}
