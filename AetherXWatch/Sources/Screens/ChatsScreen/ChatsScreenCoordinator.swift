//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

final class ChatsScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ChatsScreenViewModel

    var actionsPublisher: AnyPublisher<ChatsScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    init(clientProxy: ClientProxyProtocol) {
        viewModel = ChatsScreenViewModel(clientProxy: clientProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(ChatsScreen(context: viewModel.context))
    }
}
