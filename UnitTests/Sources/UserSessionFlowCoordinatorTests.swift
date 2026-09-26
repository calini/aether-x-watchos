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
struct UserSessionFlowCoordinatorTests {
    @Test
    func passwordSignInPresentsVerification() async throws {
        let setup = Setup()
        setup.clientProxy.sessionVerificationControllerReturnValue = SessionVerificationControllerProxyMock.idle
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, showsVerificationOnStart: true)

        coordinator.start()

        try await waitUntil { coordinator.isPresentingVerification }
    }

    @Test
    func restoredSessionsDoNotPresentVerification() {
        let setup = Setup()
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy)

        coordinator.start()

        #expect(!coordinator.isPreparingVerification)
        #expect(!coordinator.isPresentingVerification)
    }

    @Test
    func dismissingVerificationHidesIt() async throws {
        let setup = Setup()
        setup.clientProxy.sessionVerificationControllerReturnValue = SessionVerificationControllerProxyMock.idle
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy)
        coordinator.start()

        coordinator.presentVerification()
        try await waitUntil { coordinator.isPresentingVerification }
        coordinator.verificationScreen?.send(viewAction: .dismiss)

        try await waitUntil { !coordinator.isPresentingVerification }
    }

    @Test
    func presentingTwiceWhilePreparingPresentsOnce() async throws {
        let setup = Setup()
        let gate = AsyncGate()
        let controllerProxy = SessionVerificationControllerProxyMock.idle
        setup.clientProxy.sessionVerificationControllerClosure = {
            await gate.wait()
            return controllerProxy
        }
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, showsVerificationOnStart: true)

        coordinator.start()
        coordinator.presentVerification()
        await gate.open()

        try await waitUntil { coordinator.isPresentingVerification }
        #expect(setup.clientProxy.sessionVerificationControllerCallsCount == 1)
    }

    @Test
    func swipingAwayAnActiveVerificationCancelsIt() async throws {
        let setup = Setup()
        let controllerProxy = SessionVerificationControllerProxyMock.idle
        setup.clientProxy.sessionVerificationControllerReturnValue = controllerProxy
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, showsVerificationOnStart: true)
        coordinator.start()
        try await waitUntil { coordinator.isPresentingVerification }
        coordinator.verificationScreen?.send(viewAction: .start)

        coordinator.dismissVerification()

        #expect(!coordinator.isPresentingVerification)
        try await waitUntil { controllerProxy.cancelVerificationCallsCount == 1 }
    }

    @Test
    func swipingAwayAnIdleVerificationDoesNotCancel() async throws {
        let setup = Setup()
        let controllerProxy = SessionVerificationControllerProxyMock.idle
        setup.clientProxy.sessionVerificationControllerReturnValue = controllerProxy
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, showsVerificationOnStart: true)
        coordinator.start()
        try await waitUntil { coordinator.isPresentingVerification }
        let context = coordinator.verificationScreen

        coordinator.dismissVerification()

        #expect(!coordinator.isPresentingVerification)
        #expect(context?.viewState.step == .intro)
    }
}
