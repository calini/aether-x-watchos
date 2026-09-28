//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import AetherXWatch
import Testing

struct AttachmentsScreenViewModelTests {
    @Test
    func locationIsForwarded() {
        let viewModel = AttachmentsScreenViewModel()
        var actions: [AttachmentsScreenViewModelAction] = []
        let cancellable = viewModel.actionsPublisher.sink { actions.append($0) }

        viewModel.context.send(viewAction: .location)

        #expect(actions == [.location])
        cancellable.cancel()
    }

    @Test
    func voiceMessageIsForwarded() {
        let viewModel = AttachmentsScreenViewModel()
        var actions: [AttachmentsScreenViewModelAction] = []
        let cancellable = viewModel.actionsPublisher.sink { actions.append($0) }

        viewModel.context.send(viewAction: .voiceMessage)

        #expect(actions == [.voiceMessage])
        cancellable.cancel()
    }
}
