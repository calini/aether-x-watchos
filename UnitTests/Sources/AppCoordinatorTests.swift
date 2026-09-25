//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import SwiftUI
import Testing

@Suite
struct AppCoordinatorTests {
    @Test
    func withoutASessionTheUserSignsIn() async {
        let (coordinator, restorer, _, _) = makeCoordinator()
        restorer.restoreReturnValue = .failure(.noSession)

        await coordinator.start()

        #expect(coordinator.phase == .signedOut)
    }

    @Test
    func aRestoredSessionStartsSyncingWhenActive() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)

        await coordinator.start()
        coordinator.handleScenePhase(.active)

        #expect(coordinator.phase == .signedIn)
        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }
    }

    @Test
    // Goes active first (so sync is actually running): with the redundant-call skip in place, backgrounding
    // straight from launch would be a no-op stop rather than exercising the transition this test is about.
    func goingToTheBackgroundStopsSync() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        coordinator.handleScenePhase(.active)
        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }

        coordinator.handleScenePhase(.background)

        try await waitUntil { setup.clientProxy.stopSyncCallsCount == 1 }
    }

    @Test
    func inactiveAlsoStopsSync() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        coordinator.handleScenePhase(.active)
        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }

        coordinator.handleScenePhase(.inactive)

        try await waitUntil { setup.clientProxy.stopSyncCallsCount == 1 }
    }

    @Test
    func rapidPhaseFlappingAppliesInOrderAndEndsStarted() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        var callOrder: [String] = []
        setup.clientProxy.startSyncClosure = { callOrder.append("start") }
        setup.clientProxy.stopSyncClosure = { callOrder.append("stop") }

        coordinator.handleScenePhase(.active)
        coordinator.handleScenePhase(.background)
        coordinator.handleScenePhase(.active)

        try await waitUntil { callOrder.last == "start" }
        #expect(callOrder.last == "start")
    }

    @Test
    func redundantActivePhaseDoesNotStartSyncTwice() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        coordinator.handleScenePhase(.active)
        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }

        coordinator.handleScenePhase(.active)
        for _ in 0..<20 { await Task.yield() }

        #expect(setup.clientProxy.startSyncCallsCount == 1)
    }

    @Test
    func aFailedRestoreFallsBackToSignIn() async {
        let (coordinator, restorer, _, _) = makeCoordinator()
        restorer.restoreReturnValue = .failure(.restoreFailed)

        await coordinator.start()

        #expect(coordinator.phase == .signedOut)
    }

    @Test
    func authErrorsClearTheSession() async throws {
        let (coordinator, restorer, sessionStore, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        setup.actions.send(.authError(isSoftLogout: false))

        try await waitUntil { coordinator.phase == .signedOut }
        #expect(sessionStore.clearCallsCount == 1)
    }

    @Test
    func signingOutLogsOutAndClears() async throws {
        let (coordinator, restorer, sessionStore, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        await coordinator.signOut()

        #expect(setup.clientProxy.logoutCallsCount == 1)
        #expect(sessionStore.clearCallsCount == 1)
        #expect(coordinator.phase == .signedOut)
    }

    // MARK: - Helpers

    private func makeCoordinator() -> (AppCoordinator, UserSessionRestorerMock, SessionStoreMock, Setup) {
        let restorer = UserSessionRestorerMock()
        let sessionStore = SessionStoreMock()
        let coordinator = AppCoordinator(sessionStore: sessionStore, restorer: restorer, qrLoginService: QRLoginServiceMock())
        return (coordinator, restorer, sessionStore, Setup())
    }
}
