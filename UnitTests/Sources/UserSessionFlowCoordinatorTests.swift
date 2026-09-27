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
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, locationServices: setup.locationServices, voiceMessageServices: setup.voiceMessageServices, showsVerificationOnStart: true)

        coordinator.start()

        try await waitUntil { coordinator.isPresentingVerification }
    }

    @Test
    func restoredSessionsDoNotPresentVerification() {
        let setup = Setup()
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, locationServices: setup.locationServices, voiceMessageServices: setup.voiceMessageServices)

        coordinator.start()

        #expect(!coordinator.isPresentingVerification)
    }

    @Test
    func dismissingVerificationHidesIt() async throws {
        let setup = Setup()
        setup.clientProxy.sessionVerificationControllerReturnValue = SessionVerificationControllerProxyMock.idle
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, locationServices: setup.locationServices, voiceMessageServices: setup.voiceMessageServices)
        coordinator.start()

        coordinator.presentVerification()
        try await waitUntil { coordinator.isPresentingVerification }
        coordinator.verificationScreen?.send(viewAction: .dismiss)

        try await waitUntil { !coordinator.isPresentingVerification }
    }

    @Test
    func presentingTwicePresentsOnce() async throws {
        let setup = Setup()
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, locationServices: setup.locationServices, voiceMessageServices: setup.voiceMessageServices, showsVerificationOnStart: true)
        coordinator.start()
        try await waitUntil { coordinator.isPresentingVerification }
        let context = coordinator.verificationScreen

        coordinator.presentVerification()

        #expect(coordinator.verificationScreen === context)
    }

    /// Right after a password sign-in the controller isn't available yet (the own identity hasn't been
    /// downloaded), so it is only fetched once the user taps Start.
    @Test
    func startFetchesTheControllerWhenTapped() async throws {
        let setup = Setup()
        let controllerProxy = SessionVerificationControllerProxyMock.idle
        setup.clientProxy.sessionVerificationControllerReturnValue = nil
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, locationServices: setup.locationServices, voiceMessageServices: setup.voiceMessageServices, showsVerificationOnStart: true)
        coordinator.start()
        try await waitUntil { coordinator.isPresentingVerification }
        #expect(setup.clientProxy.sessionVerificationControllerCallsCount == 0)

        setup.clientProxy.sessionVerificationControllerReturnValue = controllerProxy
        coordinator.verificationScreen?.send(viewAction: .start)

        try await waitUntil { controllerProxy.requestDeviceVerificationCallsCount == 1 }
    }

    @Test
    func swipingAwayWhileWaitingForTheControllerCancels() async throws {
        let setup = Setup()
        setup.clientProxy.sessionVerificationControllerReturnValue = nil
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, locationServices: setup.locationServices, voiceMessageServices: setup.voiceMessageServices, showsVerificationOnStart: true)
        coordinator.start()
        try await waitUntil { coordinator.isPresentingVerification }
        let context = coordinator.verificationScreen
        context?.send(viewAction: .start)
        try await waitUntil { setup.clientProxy.sessionVerificationControllerCallsCount == 1 }

        coordinator.dismissVerification()

        #expect(!coordinator.isPresentingVerification)
        #expect(context?.viewState.step == .cancelled)
    }

    @Test
    func swipingAwayAnActiveVerificationCancelsIt() async throws {
        let setup = Setup()
        let controllerProxy = SessionVerificationControllerProxyMock.idle
        setup.clientProxy.sessionVerificationControllerReturnValue = controllerProxy
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, locationServices: setup.locationServices, voiceMessageServices: setup.voiceMessageServices, showsVerificationOnStart: true)
        coordinator.start()
        try await waitUntil { coordinator.isPresentingVerification }
        coordinator.verificationScreen?.send(viewAction: .start)
        try await waitUntil { controllerProxy.requestDeviceVerificationCallsCount == 1 }

        coordinator.dismissVerification()

        #expect(!coordinator.isPresentingVerification)
        try await waitUntil { controllerProxy.cancelVerificationCallsCount == 1 }
    }

    @Test
    func swipingAwayAnIdleVerificationDoesNotCancel() async throws {
        let setup = Setup()
        let controllerProxy = SessionVerificationControllerProxyMock.idle
        setup.clientProxy.sessionVerificationControllerReturnValue = controllerProxy
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, locationServices: setup.locationServices, voiceMessageServices: setup.voiceMessageServices, showsVerificationOnStart: true)
        coordinator.start()
        try await waitUntil { coordinator.isPresentingVerification }
        let context = coordinator.verificationScreen

        coordinator.dismissVerification()

        #expect(!coordinator.isPresentingVerification)
        #expect(context?.viewState.step == .intro)
    }
}
