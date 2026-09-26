//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Testing

@Suite
struct ServerSelectionScreenViewModelTests {
    @Test
    func prefillsTheDefaultServer() {
        let viewModel = ServerSelectionScreenViewModel(authenticationService: AuthenticationServiceMock())
        #expect(viewModel.context.viewState.bindings.server == "matrix.org")
        #expect(viewModel.context.viewState.canContinue)
    }

    @Test
    func emptyInputCannotContinue() {
        let viewModel = ServerSelectionScreenViewModel(authenticationService: AuthenticationServiceMock())
        viewModel.context.server = "   "
        #expect(!viewModel.context.viewState.canContinue)
    }

    @Test
    func trimsInput() async throws {
        let service = AuthenticationServiceMock()
        service.configureServerReturnValue = .success(LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: false))
        let viewModel = ServerSelectionScreenViewModel(authenticationService: service)
        viewModel.context.server = "  https://Matrix.org  "

        viewModel.context.send(viewAction: .continue)

        try await waitUntil { service.configureServerCallsCount == 1 }
        #expect(service.configureServerReceivedServer == "https://Matrix.org")
    }

    @Test
    func successReportsTheOptions() async throws {
        let options = LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: false)
        let service = AuthenticationServiceMock()
        service.configureServerReturnValue = .success(options)
        let viewModel = ServerSelectionScreenViewModel(authenticationService: service)
        var configured: LoginOptions?
        let cancellable = viewModel.actionsPublisher.sink { if case .configured(let value) = $0 { configured = value } }

        viewModel.context.send(viewAction: .continue)

        try await waitUntil { configured != nil }
        #expect(configured == options)
        #expect(!viewModel.context.viewState.isLoading)
        cancellable.cancel()
    }

    @Test
    func failuresShowAMessageAndAllowEditing() async throws {
        let service = AuthenticationServiceMock()
        service.configureServerReturnValue = .failure(.serverUnreachable)
        let viewModel = ServerSelectionScreenViewModel(authenticationService: service)

        viewModel.context.send(viewAction: .continue)

        try await waitUntil { viewModel.context.viewState.errorMessage == WatchStrings.serverUnreachable }
        #expect(!viewModel.context.viewState.isLoading)
        viewModel.context.server = "example.org"
        #expect(viewModel.context.viewState.errorMessage == nil)
    }

    @Test
    func retryingTheSameInputHidesTheOldError() async throws {
        let service = AuthenticationServiceMock()
        service.configureServerReturnValue = .failure(.serverUnreachable)
        let viewModel = ServerSelectionScreenViewModel(authenticationService: service)
        viewModel.context.send(viewAction: .continue)
        try await waitUntil { viewModel.context.viewState.errorMessage == WatchStrings.serverUnreachable }

        let gate = AsyncGate()
        service.configureServerClosure = { _ in
            await gate.wait()
            return .failure(.serverNotSupported)
        }
        viewModel.context.send(viewAction: .continue)

        try await waitUntil { service.configureServerCallsCount == 2 }
        #expect(viewModel.context.viewState.isLoading)
        #expect(viewModel.context.viewState.errorMessage == nil)
        await gate.open()
        try await waitUntil { viewModel.context.viewState.errorMessage == WatchStrings.serverNotSupported }
    }
}
