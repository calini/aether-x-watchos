//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Observation
import SwiftUI

/// Decides between the sign-in flow and the signed-in session, and drives sync from the app lifecycle.
@Observable final class AppCoordinator {
    enum Phase: Equatable {
        case launching
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .launching

    @ObservationIgnored private let sessionStore: SessionStoreProtocol
    @ObservationIgnored private let restorer: UserSessionRestorerProtocol
    @ObservationIgnored private let authenticationService: AuthenticationServiceProtocol
    @ObservationIgnored private let qrLoginService: QRLoginServiceProtocol
    @ObservationIgnored private let makeLocationServices: @MainActor (ClientProxyProtocol) -> LocationServices
    @ObservationIgnored private var clientProxy: ClientProxyProtocol?
    /// Owned here rather than by the session's flow: built before sync starts, and stopped before logging out.
    @ObservationIgnored private var locationServices: LocationServices?
    @ObservationIgnored private var liveLocationRestoreCancellable: AnyCancellable?
    @ObservationIgnored private var liveLocationRestoreTask: Task<Void, Never>?
    @ObservationIgnored private var liveLocationStateCancellable: AnyCancellable?
    /// The SDK sends and stops our live share against the `beacon_info` it last synced, so sync runs throughout.
    @ObservationIgnored private var isSharingLiveLocation = false
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var isSigningOut = false
    @ObservationIgnored private var isSyncRunning = false
    @ObservationIgnored private var lifecycleTask: Task<Void, Never>?
    @ObservationIgnored private var lifecycleGeneration = 0
    private var authenticationFlow: AuthenticationFlowCoordinator?
    private var userSessionFlow: UserSessionFlowCoordinator?

    private var shouldSync: Bool {
        isActive || isSharingLiveLocation
    }

    fileprivate var currentView: AnyView {
        switch phase {
        case .launching: AnyView(ProgressView())
        case .signedOut: authenticationFlow?.toPresentable() ?? AnyView(ProgressView())
        case .signedIn: userSessionFlow?.toPresentable() ?? AnyView(ProgressView())
        }
    }

    init(sessionStore: SessionStoreProtocol,
         restorer: UserSessionRestorerProtocol,
         authenticationService: AuthenticationServiceProtocol,
         qrLoginService: QRLoginServiceProtocol,
         makeLocationServices: @escaping @MainActor (ClientProxyProtocol) -> LocationServices = LocationServices.live(for:)) {
        self.sessionStore = sessionStore
        self.restorer = restorer
        self.authenticationService = authenticationService
        self.qrLoginService = qrLoginService
        self.makeLocationServices = makeLocationServices
    }

    func start() async {
        guard phase == .launching, !isStarting else { return }
        isStarting = true
        switch await restorer.restore() {
        case .success(let clientProxy):
            showSession(clientProxy)
        case .failure:
            showAuthentication()
        }
    }

    /// Any phase other than `.active` (e.g. `.inactive`, which watchOS delivers first when the wrist lowers)
    /// stops sync, unless a live location share is running.
    @discardableResult
    func handleScenePhase(_ scenePhase: ScenePhase) -> Task<Void, Never> {
        isActive = scenePhase == .active
        return scheduleSyncTransition(shouldRun: shouldSync)
    }

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }

        MXLog.info("Signing out")
        // Its stop needs the session, and a share left running would keep sending from a signed-out watch.
        await stopLiveLocation().value
        let oldClientProxy = clientProxy
        await teardownSync(of: oldClientProxy, wasRunning: isSyncRunning).value
        await oldClientProxy?.logout()
        clearSession()
    }

    func toPresentable() -> AnyView {
        AnyView(AppCoordinatorView(coordinator: self))
    }

    private func showAuthentication() {
        cancellables.removeAll()
        clientProxy = nil
        userSessionFlow = nil

        let flow = AuthenticationFlowCoordinator(authenticationService: authenticationService, qrLoginService: qrLoginService)
        flow.signedInPublisher
            .sink { [weak self] signedIn in self?.showSession(signedIn.clientProxy, needsVerification: signedIn.needsVerification) }
            .store(in: &cancellables)
        flow.start()
        authenticationFlow = flow
        phase = .signedOut
    }

    private func showSession(_ clientProxy: ClientProxyProtocol, needsVerification: Bool = false) {
        cancellables.removeAll()
        authenticationFlow = nil
        self.clientProxy = clientProxy

        clientProxy.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .authError:
                    // Soft logout would need a re-login flow; the watch simply signs in again.
                    self?.clearSession()
                }
            }
            .store(in: &cancellables)

        // Before sync starts, so the live share sees every update to our own shares.
        let locationServices = makeLocationServices(clientProxy)
        self.locationServices = locationServices
        observeLiveLocationState(locationServices.liveLocationService)
        restoreLiveLocation(locationServices.liveLocationService, roomSummaryProvider: clientProxy.roomSummaryProvider)

        let flow = UserSessionFlowCoordinator(clientProxy: clientProxy, locationServices: locationServices, showsVerificationOnStart: needsVerification)
        flow.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signOut: Task { await self?.signOut() }
                }
            }
            .store(in: &cancellables)
        flow.start()
        userSessionFlow = flow
        phase = .signedIn

        // Cached chats show straight away, without waiting for sync (i.e. an `.active` scene phase).
        Task { await clientProxy.roomSummaryProvider.start() }
        scheduleSyncTransition(shouldRun: shouldSync)
    }

    private func clearSession() {
        stopLiveLocation()
        teardownSync(of: clientProxy, wasRunning: isSyncRunning)
        sessionStore.clear()
        showAuthentication()
    }

    private func observeLiveLocationState(_ liveLocationService: LiveLocationServiceProtocol) {
        liveLocationStateCancellable = liveLocationService.statePublisher
            .map { $0 != .idle }
            .sink { [weak self] isSharing in
                guard let self, isSharing != isSharingLiveLocation else { return }
                isSharingLiveLocation = isSharing
                scheduleSyncTransition(shouldRun: shouldSync)
            }
    }

    /// Resumes a share from before a relaunch straight away, and again once the room list has loaded
    /// in case its room wasn't available yet.
    private func restoreLiveLocation(_ liveLocationService: LiveLocationServiceProtocol, roomSummaryProvider: RoomSummaryProviderProtocol) {
        liveLocationRestoreTask = Task { await liveLocationService.restore() }
        liveLocationRestoreCancellable = roomSummaryProvider.roomsPublisher
            .first { !$0.isEmpty }
            .sink { [weak self] _ in
                self?.liveLocationRestoreTask = Task { await liveLocationService.restore() }
            }
    }

    /// Detaches the session's live share straight away, then waits for any restore before stopping it.
    @discardableResult
    private func stopLiveLocation() -> Task<Void, Never> {
        let liveLocationService = locationServices?.liveLocationService
        let restoreTask = liveLocationRestoreTask
        locationServices = nil
        liveLocationStateCancellable = nil
        isSharingLiveLocation = false
        liveLocationRestoreCancellable = nil
        liveLocationRestoreTask = nil
        return Task {
            await restoreTask?.value
            await liveLocationService?.stop()
        }
    }

    /// Chains onto any in-flight start/stop so a fast run of phase changes applies in order: a request
    /// dropped once a later one supersedes it, and a start/stop skipped once it would be a no-op.
    @discardableResult
    private func scheduleSyncTransition(shouldRun: Bool) -> Task<Void, Never> {
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        let previousTask = lifecycleTask
        let clientProxy = clientProxy

        let task = Task { [weak self] in
            await previousTask?.value
            guard let self, generation == self.lifecycleGeneration, let clientProxy else { return }

            if shouldRun, !self.isSyncRunning {
                self.isSyncRunning = true
                await clientProxy.startSync()
            } else if !shouldRun, self.isSyncRunning {
                self.isSyncRunning = false
                await clientProxy.stopSync()
            }
        }
        lifecycleTask = task
        return task
    }

    /// Stops a session's proxy unconditionally once any earlier transition finishes, then marks sync as
    /// stopped. Unlike `scheduleSyncTransition`, this is never dropped by the generation check — a session
    /// ending must always stop its old proxy, even if a later request (e.g. a fresh sign-in) is already
    /// queued behind it. `wasRunning` and the proxy are snapshotted synchronously at call time so a
    /// caller's own state changes (clearing `clientProxy`, resetting `isSyncRunning`) can't race this.
    @discardableResult
    private func teardownSync(of clientProxy: ClientProxyProtocol?, wasRunning: Bool) -> Task<Void, Never> {
        lifecycleGeneration += 1
        let previousTask = lifecycleTask

        let task = Task { [weak self] in
            await previousTask?.value
            if wasRunning {
                await clientProxy?.stopSync()
            }
            self?.isSyncRunning = false
        }
        lifecycleTask = task
        return task
    }
}

private struct AppCoordinatorView: View {
    let coordinator: AppCoordinator

    var body: some View {
        coordinator.currentView
    }
}
