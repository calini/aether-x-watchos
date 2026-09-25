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
    func goingToTheBackgroundStopsSync() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        coordinator.handleScenePhase(.background)

        try await waitUntil { setup.clientProxy.stopSyncCallsCount == 1 }
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
