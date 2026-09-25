//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Foundation
import Testing

@Suite
struct ChatsScreenViewModelTests {
    @Test
    func roomsAndSyncStateAreShown() async throws {
        let setup = Setup()
        let viewModel = ChatsScreenViewModel(clientProxy: setup.clientProxy)
        #expect(viewModel.context.viewState.isLoading)

        setup.rooms.send([.fixture(id: "!a:x", name: "Alice")])
        setup.syncState.send(.offline)

        try await waitUntil { viewModel.context.viewState.rooms.map(\.id) == ["!a:x"] }
        #expect(!viewModel.context.viewState.isLoading)
        #expect(viewModel.context.viewState.syncState == .offline)
    }

    @Test
    func selectingARoomOpensIt() async throws {
        let setup = Setup()
        let viewModel = ChatsScreenViewModel(clientProxy: setup.clientProxy)
        setup.rooms.send([.fixture(id: "!a:x", name: "Alice")])
        try await waitUntil { !viewModel.context.viewState.rooms.isEmpty }
        var opened: RoomSummary?
        let cancellable = viewModel.actionsPublisher.sink { if case .openRoom(let room) = $0 { opened = room } }

        viewModel.context.send(viewAction: .selectRoom("!a:x"))

        #expect(opened?.name == "Alice")
        cancellable.cancel()
    }

    @Test
    func settingsCanBeOpened() {
        let viewModel = ChatsScreenViewModel(clientProxy: Setup().clientProxy)
        var openedSettings = false
        let cancellable = viewModel.actionsPublisher.sink { if case .openSettings = $0 { openedSettings = true } }

        viewModel.context.send(viewAction: .openSettings)

        #expect(openedSettings)
        cancellable.cancel()
    }
}

// MARK: - Helpers

struct Setup {
    let rooms = CurrentValueSubject<[RoomSummary], Never>([])
    let syncState = CurrentValueSubject<SyncState, Never>(.running)
    let verification = CurrentValueSubject<SessionVerification, Never>(.verified)
    let actions = PassthroughSubject<ClientProxyAction, Never>()
    let clientProxy = ClientProxyMock()

    init() {
        let provider = RoomSummaryProviderMock()
        provider.roomsPublisher = rooms.eraseToAnyPublisher()
        clientProxy.roomSummaryProvider = provider
        clientProxy.syncStatePublisher = syncState.eraseToAnyPublisher()
        clientProxy.verificationStatePublisher = verification.eraseToAnyPublisher()
        clientProxy.actionsPublisher = actions.eraseToAnyPublisher()
        clientProxy.userID = "@me:example.org"
        clientProxy.loadDisplayNameReturnValue = "Me"
    }
}

extension RoomSummary {
    static func fixture(id: String, name: String, isDirect: Bool = true, unreadCount: Int = 0) -> RoomSummary {
        RoomSummary(id: id, name: name, avatarURL: nil, isDirect: isDirect, lastMessage: "Hello", lastMessageDate: .now,
                    unreadCount: unreadCount, hasUnreadMentions: false, isMarkedUnread: false)
    }
}
