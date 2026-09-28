//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import AetherXWatch
import Testing

@Suite
struct LoginMethodScreenViewModelTests {
    @Test
    func forwardsTheChosenMethod() {
        let viewModel = LoginMethodScreenViewModel(options: LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: true))
        var actions: [LoginMethodScreenViewModelAction] = []
        let cancellable = viewModel.actionsPublisher.sink { actions.append($0) }

        viewModel.context.send(viewAction: .password)
        viewModel.context.send(viewAction: .qrCode)

        #expect(actions == [.password, .qrCode])
        cancellable.cancel()
    }

    @Test
    func unsupportedMethodsAreIgnored() {
        let viewModel = LoginMethodScreenViewModel(options: LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: false))
        var actions: [LoginMethodScreenViewModelAction] = []
        let cancellable = viewModel.actionsPublisher.sink { actions.append($0) }

        viewModel.context.send(viewAction: .qrCode)

        #expect(actions.isEmpty)
        cancellable.cancel()
    }
}
