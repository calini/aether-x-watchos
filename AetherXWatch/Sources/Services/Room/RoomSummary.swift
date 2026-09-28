//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

struct RoomSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarURL: URL?
    let isDirect: Bool
    let lastMessage: String?
    let lastMessageDate: Date?
    let unreadCount: Int
    let hasUnreadMentions: Bool
    let isMarkedUnread: Bool

    var hasUnread: Bool {
        unreadCount > 0 || isMarkedUnread
    }
}

extension RoomSummary {
    init(roomInfo: RoomInfo, latestEvent: LatestEventValue) {
        id = roomInfo.id
        name = roomInfo.displayName ?? roomInfo.rawName ?? roomInfo.id
        avatarURL = roomInfo.avatarUrl.flatMap(URL.init(string:))
        isDirect = roomInfo.isDirect
        lastMessage = RoomSummaryPreview.text(for: latestEvent, isDirect: roomInfo.isDirect)
        lastMessageDate = RoomSummaryPreview.date(for: latestEvent)
        unreadCount = Int(roomInfo.numUnreadMessages)
        hasUnreadMentions = roomInfo.numUnreadMentions > 0
        isMarkedUnread = roomInfo.isMarkedUnread
    }
}
