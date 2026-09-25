//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Observation
import SwiftUI

enum UserSessionRoute: Hashable {
    case chat(roomID: String, name: String, isDirect: Bool)
    case settings
}

enum UserSessionFlowCoordinatorAction {
    case signOut
}

/// The signed-in flow: Chats → Chat, and Settings, in one NavigationStack.
final class UserSessionFlowCoordinator: CoordinatorProtocol {
    @Observable final class Navigation {
        var path: [UserSessionRoute] = []
    }

    private let clientProxy: ClientProxyProtocol
    private let chatsCoordinator: ChatsScreenCoordinator
    private let navigation = Navigation()
    private let actionsSubject = PassthroughSubject<UserSessionFlowCoordinatorAction, Never>()
    private var childCoordinators: [UserSessionRoute: CoordinatorProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()

    var actionsPublisher: AnyPublisher<UserSessionFlowCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
        chatsCoordinator = ChatsScreenCoordinator(clientProxy: clientProxy)
    }

    func start() {
        chatsCoordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .openRoom(let room):
                    self?.navigation.path.append(.chat(roomID: room.id, name: room.name, isDirect: room.isDirect))
                case .openSettings:
                    self?.navigation.path.append(.settings)
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        let clientProxy = clientProxy
        return AnyView(UserSessionFlowView(navigation: navigation,
                                            root: chatsCoordinator.toPresentable(),
                                            destination: { [weak self] route in self?.destination(for: route) ?? AnyView(EmptyView()) })
            .environment(\.mediaLoader, MediaLoader { source, width, height in
                await clientProxy.loadThumbnail(for: source, width: width, height: height)
            }))
    }

    private func destination(for route: UserSessionRoute) -> AnyView {
        if let coordinator = childCoordinators[route] {
            return coordinator.toPresentable()
        }

        let coordinator: CoordinatorProtocol
        switch route {
        case .chat(_, let name, _):
            // Replaced by the chat screen in Task 17.
            coordinator = PlaceholderCoordinator(title: name)
        case .settings:
            let settings = SettingsScreenCoordinator(clientProxy: clientProxy)
            settings.actionsPublisher
                .sink { [weak self] action in
                    switch action {
                    case .signOut: self?.actionsSubject.send(.signOut)
                    }
                }
                .store(in: &cancellables)
            coordinator = settings
        }

        coordinator.start()
        childCoordinators[route] = coordinator
        return coordinator.toPresentable()
    }
}

private struct UserSessionFlowView: View {
    @Bindable var navigation: UserSessionFlowCoordinator.Navigation
    let root: AnyView
    let destination: (UserSessionRoute) -> AnyView

    var body: some View {
        NavigationStack(path: $navigation.path) {
            root.navigationDestination(for: UserSessionRoute.self) { route in destination(route) }
        }
    }
}

private final class PlaceholderCoordinator: CoordinatorProtocol {
    private let title: String

    init(title: String) {
        self.title = title
    }

    func toPresentable() -> AnyView {
        AnyView(Text(title))
    }
}
