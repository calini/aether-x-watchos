//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import Testing

@Suite
struct PasswordLoginScreenViewModelTests {
    @Test
    func signInNeedsBothFields() {
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: AuthenticationServiceMock())
        #expect(!viewModel.context.viewState.canSignIn)
        viewModel.context.username = "alice"
        #expect(!viewModel.context.viewState.canSignIn)
        viewModel.context.password = "secret"
        #expect(viewModel.context.viewState.canSignIn)
    }

    @Test
    func successEmitsSignedIn() async throws {
        let service = AuthenticationServiceMock()
        let clientProxy = ClientProxyMock()
        service.loginUsernamePasswordReturnValue = .success(clientProxy)
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: service)
        var signedIn: ClientProxyProtocol?
        let cancellable = viewModel.actionsPublisher.sink { if case .signedIn(let proxy) = $0 { signedIn = proxy } }
        viewModel.context.username = " alice "
        viewModel.context.password = "secret"

        viewModel.context.send(viewAction: .signIn)

        try await waitUntil { signedIn != nil }
        #expect(signedIn === clientProxy)
        #expect(service.loginUsernamePasswordReceivedArguments?.username == "alice")
        cancellable.cancel()
    }

    @Test
    func wrongPasswordKeepsUsernameAndClearsPassword() async throws {
        let service = AuthenticationServiceMock()
        service.loginUsernamePasswordReturnValue = .failure(.invalidCredentials)
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: service)
        viewModel.context.username = "alice"
        viewModel.context.password = "wrong"

        viewModel.context.send(viewAction: .signIn)

        try await waitUntil { viewModel.context.viewState.errorMessage == WatchStrings.wrongCredentials }
        #expect(viewModel.context.viewState.bindings.username == "alice")
        #expect(viewModel.context.viewState.bindings.password.isEmpty)
        #expect(!viewModel.context.viewState.isLoading)
    }

    @Test
    func rateLimitingIsExplained() async throws {
        let service = AuthenticationServiceMock()
        service.loginUsernamePasswordReturnValue = .failure(.rateLimited)
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: service)
        viewModel.context.username = "alice"
        viewModel.context.password = "secret"

        viewModel.context.send(viewAction: .signIn)

        try await waitUntil { viewModel.context.viewState.errorMessage == WatchStrings.rateLimited }
    }
}
