//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import AetherXWatch
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
