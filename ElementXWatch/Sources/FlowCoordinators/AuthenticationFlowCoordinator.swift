//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

/// The signed-out flow: currently only QR login.
final class AuthenticationFlowCoordinator: CoordinatorProtocol {
    private let screenCoordinator: QRLoginScreenCoordinator
    private let signedInSubject = PassthroughSubject<ClientProxyProtocol, Never>()
    private var cancellables = Set<AnyCancellable>()

    var signedInPublisher: AnyPublisher<ClientProxyProtocol, Never> {
        signedInSubject.eraseToAnyPublisher()
    }

    init(qrLoginService: QRLoginServiceProtocol) {
        screenCoordinator = QRLoginScreenCoordinator(qrLoginService: qrLoginService)
    }

    func start() {
        screenCoordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let clientProxy):
                    self?.signedInSubject.send(clientProxy)
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        AnyView(NavigationStack { screenCoordinator.toPresentable() })
    }
}
