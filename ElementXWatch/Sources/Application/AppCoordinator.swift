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
    @ObservationIgnored private let qrLoginService: QRLoginServiceProtocol
    @ObservationIgnored private var clientProxy: ClientProxyProtocol?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var isSyncRunning = false
    @ObservationIgnored private var lifecycleTask: Task<Void, Never>?
    @ObservationIgnored private var lifecycleGeneration = 0
    private var authenticationFlow: AuthenticationFlowCoordinator?
    private var userSessionFlow: UserSessionFlowCoordinator?

    fileprivate var currentView: AnyView {
        switch phase {
        case .launching: AnyView(ProgressView())
        case .signedOut: authenticationFlow?.toPresentable() ?? AnyView(ProgressView())
        case .signedIn: userSessionFlow?.toPresentable() ?? AnyView(ProgressView())
        }
    }

    init(sessionStore: SessionStoreProtocol, restorer: UserSessionRestorerProtocol, qrLoginService: QRLoginServiceProtocol) {
        self.sessionStore = sessionStore
        self.restorer = restorer
        self.qrLoginService = qrLoginService
    }

    func start() async {
        switch await restorer.restore() {
        case .success(let clientProxy):
            showSession(clientProxy)
        case .failure:
            showAuthentication()
        }
    }

    /// Any phase other than `.active` (e.g. `.inactive`, which watchOS delivers first when the wrist lowers) stops sync.
    func handleScenePhase(_ scenePhase: ScenePhase) {
        isActive = scenePhase == .active
        scheduleSyncTransition(shouldRun: isActive)
    }

    func signOut() async {
        MXLog.info("Signing out")
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

        let flow = AuthenticationFlowCoordinator(qrLoginService: qrLoginService)
        flow.signedInPublisher
            .sink { [weak self] clientProxy in self?.showSession(clientProxy) }
            .store(in: &cancellables)
        flow.start()
        authenticationFlow = flow
        phase = .signedOut
    }

    private func showSession(_ clientProxy: ClientProxyProtocol) {
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

        let flow = UserSessionFlowCoordinator(clientProxy: clientProxy)
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

        scheduleSyncTransition(shouldRun: isActive)
    }

    private func clearSession() {
        teardownSync(of: clientProxy, wasRunning: isSyncRunning)
        sessionStore.clear()
        showAuthentication()
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
