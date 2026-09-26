//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Foundation
import MatrixRustSDK

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
        clientProxy.ownBeaconInfoPublisher = Empty().eraseToAnyPublisher()
        clientProxy.userID = "@me:example.org"
        clientProxy.loadDisplayNameReturnValue = "Me"
    }
}

extension SessionVerificationControllerProxyMock {
    /// A controller that emits nothing and whose calls all succeed.
    @MainActor static var idle: SessionVerificationControllerProxyMock {
        let mock = SessionVerificationControllerProxyMock()
        mock.actionsPublisher = Empty().eraseToAnyPublisher()
        mock.requestDeviceVerificationReturnValue = .success(())
        mock.startSasVerificationReturnValue = .success(())
        mock.approveVerificationReturnValue = .success(())
        mock.declineVerificationReturnValue = .success(())
        mock.cancelVerificationReturnValue = .success(())
        return mock
    }
}

extension RoomSummary {
    static func fixture(id: String, name: String, isDirect: Bool = true, unreadCount: Int = 0) -> RoomSummary {
        RoomSummary(id: id, name: name, avatarURL: nil, isDirect: isDirect, lastMessage: "Hello", lastMessageDate: .now,
                    unreadCount: unreadCount, hasUnreadMentions: false, isMarkedUnread: false)
    }
}

extension EventItem {
    static func fixture(eventID: String?, body: String = "Hello", sendState: SendState = .sent, isOwn: Bool = false) -> EventItem {
        EventItem(itemID: eventID.map { .eventId(eventId: $0) } ?? .transactionId(transactionId: "txn"),
                  eventID: eventID,
                  senderID: "@bob:example.org",
                  senderName: "Bob",
                  isOwn: isOwn,
                  date: Date(timeIntervalSince1970: 1_700_000_000),
                  body: .text(AttributedString(body)),
                  replyTo: nil,
                  reactions: [],
                  isEdited: false,
                  sendState: sendState,
                  canBeRepliedTo: true)
    }
}

extension ElementXWatch.TimelineItem {
    static func event(_ id: String, body: String, isOwn: Bool = false) -> ElementXWatch.TimelineItem {
        ElementXWatch.TimelineItem(id: id, kind: .event(.fixture(eventID: "$\(id)", body: body, isOwn: isOwn)))
    }
}
