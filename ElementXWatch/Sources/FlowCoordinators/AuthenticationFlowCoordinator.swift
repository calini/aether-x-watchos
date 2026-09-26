//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Observation
import SwiftUI

enum AuthenticationRoute: Hashable {
    case method(LoginOptions)
    case password(serverName: String)
    case qrCode
}

struct SignedIn {
    let clientProxy: ClientProxyProtocol
    /// Password sign-ins start unverified; QR sign-ins arrive verified.
    let needsVerification: Bool
}

/// The signed-out flow: server → sign-in method → password or QR code, in one NavigationStack.
final class AuthenticationFlowCoordinator: CoordinatorProtocol {
    @Observable final class Navigation {
        var path: [AuthenticationRoute] = []
    }

    private let authenticationService: AuthenticationServiceProtocol
    private let qrLoginService: QRLoginServiceProtocol
    private let serverCoordinator: ServerSelectionScreenCoordinator
    private let navigation = Navigation()
    private let signedInSubject = PassthroughSubject<SignedIn, Never>()
    private var methodCoordinator: LoginMethodScreenCoordinator?
    private var passwordCoordinator: PasswordLoginScreenCoordinator?
    private var qrCoordinator: QRLoginScreenCoordinator?
    private var cancellables = Set<AnyCancellable>()

    var signedInPublisher: AnyPublisher<SignedIn, Never> {
        signedInSubject.eraseToAnyPublisher()
    }

    var path: [AuthenticationRoute] {
        navigation.path
    }

    /// Test hook: the server screen's context.
    var serverScreen: ServerSelectionScreenViewModel.Context {
        serverCoordinator.context
    }

    /// Test hook: the password screen's context, while it is on the stack.
    var passwordScreen: PasswordLoginScreenViewModel.Context? {
        passwordCoordinator?.context
    }

    /// Test hook: the QR screen's context, while it is on the stack.
    var qrScreen: QRLoginScreenViewModel.Context? {
        qrCoordinator?.context
    }

    init(authenticationService: AuthenticationServiceProtocol, qrLoginService: QRLoginServiceProtocol) {
        self.authenticationService = authenticationService
        self.qrLoginService = qrLoginService
        serverCoordinator = ServerSelectionScreenCoordinator(authenticationService: authenticationService)
    }

    func start() {
        serverCoordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .configured(let options): self?.showMethods(options)
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        AnyView(AuthenticationFlowView(navigation: navigation,
                                       root: serverCoordinator.toPresentable(),
                                       destination: { [weak self] route in self?.destination(for: route) ?? AnyView(EmptyView()) },
                                       onPathChange: { [weak self] path in self?.handlePathChange(path) }))
    }

    /// Drops coordinators whose routes left the stack; backing out to the server screen also resets the pending login.
    func handlePathChange(_ path: [AuthenticationRoute]) {
        guard !path.isEmpty else {
            methodCoordinator = nil
            passwordCoordinator = nil
            qrCoordinator = nil
            authenticationService.reset()
            return
        }

        if !path.contains(where: \.isPassword) {
            passwordCoordinator = nil
        }
        if !path.contains(.qrCode) {
            qrCoordinator = nil
        }
    }

    func showPassword(serverName: String) {
        let coordinator = PasswordLoginScreenCoordinator(serverName: serverName, authenticationService: authenticationService)
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let clientProxy): self?.signedInSubject.send(SignedIn(clientProxy: clientProxy, needsVerification: true))
                }
            }
            .store(in: &cancellables)
        passwordCoordinator = coordinator
        navigation.path.append(.password(serverName: serverName))
    }

    /// Runs on the configured server: the service signs in with the pending login.
    func showQRCode() {
        let coordinator = QRLoginScreenCoordinator(qrLoginService: qrLoginService)
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let clientProxy): self?.signedInSubject.send(SignedIn(clientProxy: clientProxy, needsVerification: false))
                }
            }
            .store(in: &cancellables)
        qrCoordinator = coordinator
        navigation.path.append(.qrCode)
    }

    private func showMethods(_ options: LoginOptions) {
        let coordinator = LoginMethodScreenCoordinator(options: options)
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .password: self?.showPassword(serverName: options.serverName)
                case .qrCode: self?.showQRCode()
                }
            }
            .store(in: &cancellables)
        methodCoordinator = coordinator
        navigation.path = [.method(options)]
    }

    private func destination(for route: AuthenticationRoute) -> AnyView {
        switch route {
        case .method: methodCoordinator?.toPresentable() ?? AnyView(EmptyView())
        case .password: passwordCoordinator?.toPresentable() ?? AnyView(EmptyView())
        case .qrCode: qrCoordinator?.toPresentable() ?? AnyView(EmptyView())
        }
    }
}

private extension AuthenticationRoute {
    var isPassword: Bool {
        if case .password = self { true } else { false }
    }
}

private struct AuthenticationFlowView: View {
    @Bindable var navigation: AuthenticationFlowCoordinator.Navigation
    let root: AnyView
    let destination: (AuthenticationRoute) -> AnyView
    let onPathChange: ([AuthenticationRoute]) -> Void

    var body: some View {
        NavigationStack(path: $navigation.path) {
            root.navigationDestination(for: AuthenticationRoute.self) { route in destination(route) }
        }
        .onChange(of: navigation.path) { _, path in onPathChange(path) }
    }
}
