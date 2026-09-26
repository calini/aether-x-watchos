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
struct AuthenticationFlowCoordinatorTests {
    @Test
    func configuredServerPushesTheMethodScreen() async throws {
        let (coordinator, service, _) = makeCoordinator()
        let options = LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: false)
        service.configureServerReturnValue = .success(options)

        coordinator.serverScreen.send(viewAction: .continue)

        try await waitUntil { coordinator.path == [.method(options)] }
    }

    @Test
    func passwordSignInIsReportedAsNeedingVerification() async throws {
        let (coordinator, service, _) = makeCoordinator()
        let proxy = ClientProxyMock()
        service.loginUsernamePasswordReturnValue = .success(proxy)
        var signedIn: SignedIn?
        let cancellable = coordinator.signedInPublisher.sink { signedIn = $0 }

        coordinator.showPassword(serverName: "matrix.org")
        let password = try #require(coordinator.passwordScreen)
        password.username = "alice"
        password.password = "secret"
        password.send(viewAction: .signIn)

        try await waitUntil { signedIn != nil }
        #expect(signedIn?.clientProxy === proxy)
        #expect(signedIn?.needsVerification == true)
        cancellable.cancel()
    }

    @Test
    func qrSignInDoesNotNeedVerification() async throws {
        let (coordinator, _, qrService) = makeCoordinator()
        let proxy = ClientProxyMock()
        qrService.loginWithGeneratedQRCodeOnProgressClosure = { _ in .success(proxy) }
        var signedIn: SignedIn?
        let cancellable = coordinator.signedInPublisher.sink { signedIn = $0 }

        coordinator.showQRCode()
        try #require(coordinator.qrScreen).send(viewAction: .start)

        try await waitUntil { signedIn != nil }
        #expect(signedIn?.needsVerification == false)
        cancellable.cancel()
    }

    @Test
    func backToServerResetsPendingLogin() {
        let (coordinator, service, _) = makeCoordinator()
        coordinator.handlePathChange([.method(LoginOptions(serverName: "a", supportsPassword: true, supportsQRCode: false))])

        coordinator.handlePathChange([])

        #expect(service.resetCallsCount == 1)
    }

    // MARK: - Helpers

    private func makeCoordinator() -> (AuthenticationFlowCoordinator, AuthenticationServiceMock, QRLoginServiceMock) {
        let service = AuthenticationServiceMock()
        let qrService = QRLoginServiceMock()
        let coordinator = AuthenticationFlowCoordinator(authenticationService: service, qrLoginService: qrService)
        coordinator.start()
        return (coordinator, service, qrService)
    }
}
