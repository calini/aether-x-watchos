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
        var verification: SessionVerificationScreenCoordinator?
    }

    private let clientProxy: ClientProxyProtocol
    private let showsVerificationOnStart: Bool
    private let chatsCoordinator: ChatsScreenCoordinator
    private let navigation = Navigation()
    private let actionsSubject = PassthroughSubject<UserSessionFlowCoordinatorAction, Never>()
    private var childCoordinators: [UserSessionRoute: CoordinatorProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    // Lives and dies with the presented verification, so a dismissed screen's late action is ignored.
    private var verificationCancellable: AnyCancellable?

    var actionsPublisher: AnyPublisher<UserSessionFlowCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    /// Test hook.
    var isPresentingVerification: Bool {
        navigation.verification != nil
    }

    /// Test hook: the verification screen's context, while it is presented.
    var verificationScreen: SessionVerificationScreenViewModel.Context? {
        navigation.verification?.context
    }

    init(clientProxy: ClientProxyProtocol, showsVerificationOnStart: Bool = false) {
        self.clientProxy = clientProxy
        self.showsVerificationOnStart = showsVerificationOnStart
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

        if showsVerificationOnStart {
            presentVerification()
        }
    }

    func toPresentable() -> AnyView {
        let clientProxy = clientProxy
        return AnyView(UserSessionFlowView(navigation: navigation,
                                            root: chatsCoordinator.toPresentable(),
                                            destination: { [weak self] route in self?.destination(for: route) ?? AnyView(EmptyView()) },
                                            onPathChange: { [weak self] in self?.pruneChildCoordinators() },
                                            onVerificationDismissed: { [weak self] in self?.dismissVerification() })
            .environment(\.mediaLoader, MediaLoader(loadThumbnail: { source, width, height in
                await clientProxy.loadThumbnail(for: source, width: width, height: height)
            }, loadContent: { source in
                await clientProxy.loadMediaContent(for: source)
            })))
    }

    /// The controller is fetched when the user taps Start: right after a password sign-in it isn't
    /// available yet, as the own identity only arrives with the first keys query.
    func presentVerification() {
        guard navigation.verification == nil else { return }
        let coordinator = SessionVerificationScreenCoordinator { [clientProxy] in await clientProxy.sessionVerificationController() }
        verificationCancellable = coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .dismiss: self?.dismissVerification()
                }
            }
        navigation.verification = coordinator
    }

    /// A swipe-down can happen mid-flow, so an in-progress verification is cancelled rather than left running.
    func dismissVerification() {
        if let context = navigation.verification?.context, context.viewState.isFlowActive {
            context.send(viewAction: .cancel)
        }
        navigation.verification = nil
        verificationCancellable = nil
    }

    private func destination(for route: UserSessionRoute) -> AnyView {
        if let coordinator = childCoordinators[route] {
            return coordinator.toPresentable()
        }

        let coordinator: CoordinatorProtocol
        switch route {
        case .chat(let roomID, let name, let isDirect):
            coordinator = ChatLoaderCoordinator(roomID: roomID, name: name, isDirect: isDirect, clientProxy: clientProxy)
        case .settings:
            let settings = SettingsScreenCoordinator(clientProxy: clientProxy)
            settings.actionsPublisher
                .sink { [weak self] action in
                    switch action {
                    case .verifySession: self?.presentVerification()
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

    /// Drops coordinators for routes no longer on the stack (e.g. after a back swipe), so a
    /// re-opened chat gets a fresh `ChatLoaderCoordinator` rather than a stale, unsubscribed one.
    private func pruneChildCoordinators() {
        let liveRoutes = Set(navigation.path)
        childCoordinators = childCoordinators.filter { liveRoutes.contains($0.key) }
    }
}

private struct UserSessionFlowView: View {
    @Bindable var navigation: UserSessionFlowCoordinator.Navigation
    let root: AnyView
    let destination: (UserSessionRoute) -> AnyView
    let onPathChange: () -> Void
    let onVerificationDismissed: () -> Void

    /// Clears the flow's state when the sheet is swiped away.
    private var isPresentingVerification: Binding<Bool> {
        Binding(get: { navigation.verification != nil },
                set: { isPresented in if !isPresented { onVerificationDismissed() } })
    }

    var body: some View {
        NavigationStack(path: $navigation.path) {
            root.navigationDestination(for: UserSessionRoute.self) { route in destination(route) }
        }
        .onChange(of: navigation.path) { _, _ in onPathChange() }
        .sheet(isPresented: isPresentingVerification) {
            if let verification = navigation.verification {
                NavigationStack { verification.toPresentable() }
            }
        }
    }
}

/// Opens the room's timeline, then shows the chat screen (or an error if the room can't be opened).
private final class ChatLoaderCoordinator: CoordinatorProtocol {
    @Observable final class Model {
        var chat: ChatScreenCoordinator?
        var failed = false
    }

    private let roomID: String
    private let name: String
    private let isDirect: Bool
    private let clientProxy: ClientProxyProtocol
    private let model = Model()

    init(roomID: String, name: String, isDirect: Bool, clientProxy: ClientProxyProtocol) {
        self.roomID = roomID
        self.name = name
        self.isDirect = isDirect
        self.clientProxy = clientProxy
    }

    func start() {
        Task { [model, roomID, name, isDirect, clientProxy] in
            if let timelineProxy = await clientProxy.timelineProxy(for: roomID) {
                model.chat = ChatScreenCoordinator(roomName: name, isDirect: isDirect, timelineProxy: timelineProxy)
            } else {
                model.failed = true
            }
        }
    }

    func toPresentable() -> AnyView {
        AnyView(ChatLoaderView(model: model, name: name))
    }
}

private struct ChatLoaderView: View {
    let model: ChatLoaderCoordinator.Model
    let name: String

    var body: some View {
        if let chat = model.chat {
            chat.toPresentable()
        } else if model.failed {
            Text(WatchStrings.couldNotOpenChat).navigationTitle(name)
        } else {
            ProgressView().navigationTitle(name)
        }
    }
}
