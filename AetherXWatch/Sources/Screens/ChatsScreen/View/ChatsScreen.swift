//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct ChatsScreen: View {
    @Bindable var context: ChatsScreenViewModel.Context

    var body: some View {
        List {
            if let banner {
                Text(banner).font(.footnote).foregroundStyle(Color.compound.textSecondary)
            }
            if context.viewState.isLoading {
                ProgressView()
            } else if context.viewState.rooms.isEmpty {
                Text(WatchStrings.noChats).foregroundStyle(Color.compound.textSecondary)
            } else {
                ForEach(context.viewState.rooms) { room in
                    Button { context.send(viewAction: .selectRoom(room.id)) } label: { RoomRow(room: room) }
                }
            }
        }
        .navigationTitle(WatchStrings.chats)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { context.send(viewAction: .openSettings) } label: { Image(compound: \.settings) }
                    .accessibilityLabel(WatchStrings.settings)
            }
        }
    }

    private var banner: String? {
        switch context.viewState.syncState {
        case .offline: WatchStrings.offline
        case .error: WatchStrings.connecting
        case .idle, .running: nil
        }
    }
}

// MARK: - Previews

struct ChatsScreen_Previews: PreviewProvider {
    static let rooms = [
        RoomSummary(id: "1", name: "Alice", avatarURL: nil, isDirect: true, lastMessage: "See you soon!", lastMessageDate: .now,
                    unreadCount: 2, hasUnreadMentions: false, isMarkedUnread: false),
        RoomSummary(id: "2", name: "Climbing crew", avatarURL: nil, isDirect: false, lastMessage: "Bob: Saturday?",
                    lastMessageDate: .now.addingTimeInterval(-3600), unreadCount: 1, hasUnreadMentions: true, isMarkedUnread: false)
    ]

    static var previews: some View {
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: rooms, syncState: .running).context) }
            .previewDisplayName("Rooms")
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: rooms, syncState: .offline).context) }
            .previewDisplayName("Offline")
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: rooms, syncState: .error).context) }
            .previewDisplayName("Connecting")
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: [], syncState: .running).context) }
            .previewDisplayName("Empty")
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: nil, syncState: .running).context) }
            .previewDisplayName("Loading")
    }

    static func makeViewModel(rooms: [RoomSummary]?, syncState: SyncState) -> ChatsScreenViewModel {
        let viewModel = ChatsScreenViewModel(clientProxy: ClientProxyMock.preview)
        viewModel.state.rooms = rooms ?? []
        viewModel.state.isLoading = rooms == nil
        viewModel.state.syncState = syncState
        return viewModel
    }
}
