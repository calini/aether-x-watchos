//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

final class ChatScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ChatScreenViewModel

    init(roomName: String, isDirect: Bool, timelineProxy: TimelineProxyProtocol) {
        viewModel = ChatScreenViewModel(roomName: roomName, isDirect: isDirect, timelineProxy: timelineProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(ChatScreen(context: viewModel.context))
    }
}
