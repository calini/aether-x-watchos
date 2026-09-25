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

    func handleScenePhase(_ scenePhase: ScenePhase) {
        isActive = scenePhase == .active
        guard let clientProxy else { return }
        Task {
            if scenePhase == .active {
                await clientProxy.startSync()
            } else if scenePhase == .background {
                await clientProxy.stopSync()
            }
        }
    }

    func signOut() async {
        MXLog.info("Signing out")
        await clientProxy?.logout()
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

        if isActive {
            Task { await clientProxy.startSync() }
        }
    }

    private func clearSession() {
        sessionStore.clear()
        showAuthentication()
    }
}

private struct AppCoordinatorView: View {
    let coordinator: AppCoordinator

    var body: some View {
        coordinator.currentView
    }
}
