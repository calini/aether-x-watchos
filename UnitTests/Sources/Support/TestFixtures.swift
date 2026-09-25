//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Foundation

/// A `ClientProxyMock` wired to publisher fixtures, shared by the chats and settings screen tests.
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
