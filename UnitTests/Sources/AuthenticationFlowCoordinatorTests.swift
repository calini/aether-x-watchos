//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Synchronization
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

    @Test
    func poppedPasswordScreenDoesNotReportALateSignIn() async throws {
        let (coordinator, service, _) = makeCoordinator()
        let gate = AsyncGate()
        service.loginUsernamePasswordClosure = { _, _ in
            await gate.wait()
            return .success(ClientProxyMock())
        }
        var signedIn: SignedIn?
        let cancellable = coordinator.signedInPublisher.sink { signedIn = $0 }
        coordinator.showPassword(serverName: "matrix.org")
        let password = try #require(coordinator.passwordScreen)
        password.username = "alice"
        password.password = "secret"
        password.send(viewAction: .signIn)
        try await waitUntil { service.loginUsernamePasswordCallsCount == 1 }

        coordinator.handlePathChange([.method(Self.options)])
        await gate.open()

        // The dropped screen's sign-in still finishes; its result must not leave the flow.
        try await waitUntil { !password.viewState.isLoading }
        #expect(coordinator.passwordScreen == nil)
        #expect(signedIn == nil)
        cancellable.cancel()
    }

    @Test
    func poppedQRScreenCancelsTheLogin() async throws {
        let (coordinator, _, qrService) = makeCoordinator()
        let proxy = ClientProxyMock()
        let didReturnCancelled = Flag()
        qrService.loginWithGeneratedQRCodeOnProgressClosure = { [didReturnCancelled] _ in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5))
            }
            didReturnCancelled.set()
            // Succeeds anyway, so only the flow's own cancellation handling keeps it from being reported.
            return .success(proxy)
        }
        var signedIn: SignedIn?
        let cancellable = coordinator.signedInPublisher.sink { signedIn = $0 }
        coordinator.showQRCode()
        try #require(coordinator.qrScreen).send(viewAction: .start)
        try await waitUntil { qrService.loginWithGeneratedQRCodeOnProgressCallsCount == 1 }

        coordinator.handlePathChange([.method(Self.options)])

        try await waitUntil { didReturnCancelled.isSet }
        #expect(coordinator.qrScreen == nil)
        #expect(signedIn == nil)
        cancellable.cancel()
    }

    // MARK: - Helpers

    private static let options = LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: true)


    private func makeCoordinator() -> (AuthenticationFlowCoordinator, AuthenticationServiceMock, QRLoginServiceMock) {
        let service = AuthenticationServiceMock()
        let qrService = QRLoginServiceMock()
        let coordinator = AuthenticationFlowCoordinator(authenticationService: service, qrLoginService: qrService)
        coordinator.start()
        return (coordinator, service, qrService)
    }
}

/// A flag set from the mock's concurrent context and read back on the main actor.
private nonisolated final class Flag: Sendable {
    private let value = Mutex(false)

    var isSet: Bool {
        value.withLock { $0 }
    }

    func set() {
        value.withLock { $0 = true }
    }
}
