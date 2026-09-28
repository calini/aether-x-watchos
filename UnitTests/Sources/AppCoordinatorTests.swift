//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
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
    // The redundant `.active` and the later `.background` are chained on the same serialized lifecycle
    // task, so waiting for the background's stop to land is a deterministic proof the redundant request
    // was already evaluated (and skipped) by then — no arbitrary yield loop needed.
    func redundantActivePhaseDoesNotStartSyncTwice() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        coordinator.handleScenePhase(.active)
        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }

        coordinator.handleScenePhase(.active)
        coordinator.handleScenePhase(.background)

        try await waitUntil { setup.clientProxy.stopSyncCallsCount == 1 }
        #expect(setup.clientProxy.startSyncCallsCount == 1)
    }

    @Test
    func aRestoredSessionStartsTheRoomListWithoutWaitingForSync() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        let provider = try #require(setup.clientProxy.roomSummaryProvider as? RoomSummaryProviderMock)

        await coordinator.start()

        try await waitUntil { provider.startCallsCount == 1 }
        #expect(setup.clientProxy.startSyncCallsCount == 0)
    }

    @Test
    func startingTwiceRestoresOnce() async {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)

        await coordinator.start()
        await coordinator.start()

        #expect(restorer.restoreCallsCount == 1)
        #expect(coordinator.phase == .signedIn)
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
    // Regression for a bug where clearSession's synchronous showAuthentication() reset isSyncRunning
    // before the queued stop ran, making it see "already stopped" and skip stopSync entirely.
    func authErrorWhileSyncingStopsTheOldClient() async throws {
        let (coordinator, restorer, sessionStore, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        coordinator.handleScenePhase(.active)
        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }

        setup.actions.send(.authError(isSoftLogout: false))

        try await waitUntil { coordinator.phase == .signedOut }
        try await waitUntil { setup.clientProxy.stopSyncCallsCount == 1 }
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

    @Test
    func signingOutTwiceLogsOutOnce() async throws {
        let (coordinator, restorer, sessionStore, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        let gate = AsyncGate()
        setup.clientProxy.logoutClosure = { await gate.wait() }

        let firstSignOut = Task { await coordinator.signOut() }
        try await waitUntil { setup.clientProxy.logoutCallsCount == 1 }
        await coordinator.signOut()
        await gate.open()
        await firstSignOut.value

        #expect(setup.clientProxy.logoutCallsCount == 1)
        #expect(sessionStore.clearCallsCount == 1)
    }

    @Test
    func signOutWhileSyncingStopsBeforeLoggingOut() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        coordinator.handleScenePhase(.active)
        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }

        var callOrder: [String] = []
        setup.clientProxy.stopSyncClosure = { callOrder.append("stop") }
        setup.clientProxy.logoutClosure = { callOrder.append("logout") }

        await coordinator.signOut()

        #expect(callOrder == ["stop", "logout"])
    }

    @Test
    func locationServicesAreBuiltBeforeSyncStarts() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        setup.clientProxy.startSyncClosure = { setup.calls.values.append("startSync") }
        // Already active, so the session requests sync as soon as it exists.
        coordinator.handleScenePhase(.active)

        await coordinator.start()

        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }
        // Otherwise the live share could miss an own-beacon update from the first sync.
        #expect(setup.calls.values == ["makeLocationServices", "makeVoiceMessageServices", "startSync"])
    }

    @Test
    func aLiveShareKeepsSyncRunningWhileTheSceneIsInactive() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        await coordinator.handleScenePhase(.active).value
        #expect(setup.clientProxy.startSyncCallsCount == 1)

        setup.liveLocationState.send(.sharing(roomID: "!a", endsAt: .distantFuture, isPaused: false))
        await coordinator.handleScenePhase(.inactive).value
        await coordinator.handleScenePhase(.background).value

        #expect(setup.clientProxy.stopSyncCallsCount == 0)

        setup.liveLocationState.send(.idle)

        try await waitUntil { setup.clientProxy.stopSyncCallsCount == 1 }
        #expect(setup.clientProxy.startSyncCallsCount == 1)
    }

    @Test
    func aLiveShareResumedInTheBackgroundStartsSync() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        await coordinator.handleScenePhase(.background).value
        #expect(setup.clientProxy.startSyncCallsCount == 0)

        setup.liveLocationState.send(.sharing(roomID: "!a", endsAt: .distantFuture, isPaused: false))

        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }
    }

    @Test
    func aSessionRestoresLiveLocationAndAgainOnceTheRoomsLoad() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)

        await coordinator.start()
        coordinator.handleScenePhase(.active)

        try await waitUntil { setup.liveLocationService.restoreCallsCount == 1 }
        setup.rooms.send([.fixture(id: "!a", name: "Alice")])
        try await waitUntil { setup.liveLocationService.restoreCallsCount == 2 }
        setup.rooms.send([.fixture(id: "!a", name: "Alice"), .fixture(id: "!b", name: "Bob")])
        try await Task.sleep(for: .milliseconds(20))
        #expect(setup.liveLocationService.restoreCallsCount == 2)
    }

    @Test
    func signingOutStopsLiveLocationBeforeLoggingOut() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        var callOrder: [String] = []
        setup.liveLocationService.stopClosure = { callOrder.append("stopLiveLocation") }
        setup.clientProxy.logoutClosure = { callOrder.append("logout") }

        await coordinator.signOut()

        #expect(callOrder == ["stopLiveLocation", "logout"])
    }

    @Test
    func authErrorsStopLiveLocation() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        setup.actions.send(.authError(isSoftLogout: false))

        try await waitUntil { setup.liveLocationService.stopCallsCount == 1 }
    }

    @Test
    func signingOutStopsVoicePlaybackAndClearsItsCache() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()
        #expect(setup.calls.values.contains("makeVoiceMessageServices"))

        var callOrder: [String] = []
        setup.voiceMessagePlayer.stopAndClearCacheClosure = { callOrder.append("stopAndClearCache") }
        setup.clientProxy.logoutClosure = { callOrder.append("logout") }

        await coordinator.signOut()

        #expect(callOrder == ["stopAndClearCache", "logout"])
    }

    @Test
    func authErrorsStopVoicePlaybackAndClearItsCache() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        setup.actions.send(.authError(isSoftLogout: false))

        try await waitUntil { setup.voiceMessagePlayer.stopAndClearCacheCallsCount == 1 }
    }

    // MARK: - Helpers

    private func makeCoordinator() -> (AppCoordinator, UserSessionRestorerMock, SessionStoreMock, Setup) {
        let restorer = UserSessionRestorerMock()
        let sessionStore = SessionStoreMock()
        let setup = Setup()
        let coordinator = AppCoordinator(sessionStore: sessionStore,
                                         restorer: restorer,
                                         authenticationService: AuthenticationServiceMock(),
                                         qrLoginService: QRLoginServiceMock(),
                                         makeLocationServices: { _ in
                                             setup.calls.values.append("makeLocationServices")
                                             return setup.locationServices
                                         },
                                         makeVoiceMessageServices: { _ in
                                             setup.calls.values.append("makeVoiceMessageServices")
                                             return setup.voiceMessageServices
                                         })
        return (coordinator, restorer, sessionStore, setup)
    }
}
