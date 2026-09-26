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
    private var serverCancellable: AnyCancellable?
    // Each child's subscription lives and dies with it, so a dropped screen's late result is ignored.
    private var methodCancellable: AnyCancellable?
    private var passwordCancellable: AnyCancellable?
    private var qrCancellable: AnyCancellable?

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
        serverCancellable = serverCoordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .configured(let options): self?.showMethods(options)
                }
            }
    }

    func toPresentable() -> AnyView {
        AnyView(AuthenticationFlowView(navigation: navigation,
                                       root: serverCoordinator.toPresentable(),
                                       destination: { [weak self] route in self?.destination(for: route) ?? AnyView(EmptyView()) },
                                       onPathChange: { [weak self] path in self?.handlePathChange(path) }))
    }

    /// Drops coordinators whose routes left the stack; backing out to the server screen also resets the pending login.
    func handlePathChange(_ path: [AuthenticationRoute]) {
        if !path.contains(where: \.isPassword) {
            passwordCoordinator = nil
            passwordCancellable = nil
        }
        if !path.contains(.qrCode) {
            dropQRCode()
        }
        if path.isEmpty {
            methodCoordinator = nil
            methodCancellable = nil
            authenticationService.reset()
        }
    }

    func showPassword(serverName: String) {
        let coordinator = PasswordLoginScreenCoordinator(serverName: serverName, authenticationService: authenticationService)
        passwordCancellable = coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let clientProxy): self?.signedInSubject.send(SignedIn(clientProxy: clientProxy, needsVerification: true))
                }
            }
        passwordCoordinator = coordinator
        navigation.path.append(.password(serverName: serverName))
    }

    /// Runs on the configured server: the service signs in with the pending login.
    func showQRCode() {
        dropQRCode()
        let coordinator = QRLoginScreenCoordinator(qrLoginService: qrLoginService)
        qrCancellable = coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let clientProxy): self?.signedInSubject.send(SignedIn(clientProxy: clientProxy, needsVerification: false))
                }
            }
        qrCoordinator = coordinator
        navigation.path.append(.qrCode)
    }

    private func showMethods(_ options: LoginOptions) {
        let coordinator = LoginMethodScreenCoordinator(options: options)
        methodCancellable = coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .password: self?.showPassword(serverName: options.serverName)
                case .qrCode: self?.showQRCode()
                }
            }
        methodCoordinator = coordinator
        navigation.path = [.method(options)]
    }

    /// The service owns an in-flight QR login's session files, so it must be stopped, not just dropped.
    private func dropQRCode() {
        qrCoordinator?.context.send(viewAction: .cancel)
        qrCoordinator = nil
        qrCancellable = nil
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
