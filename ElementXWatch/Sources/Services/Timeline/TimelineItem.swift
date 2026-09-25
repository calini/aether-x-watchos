//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// One entry per SDK timeline item (hidden ones included) so SDK diffs map 1:1 by index.
struct TimelineItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case event(EventItem)
        case dateDivider(Date)
        case readMarker
        case timelineStart
        /// State events and other items the watch doesn't show.
        case hidden
    }

    let id: String
    let kind: Kind

    var isVisible: Bool {
        switch kind {
        case .event, .dateDivider: true
        case .readMarker, .timelineStart, .hidden: false
        }
    }
}

struct EventItem: Equatable {
    let itemID: EventOrTransactionId
    let eventID: String?
    let senderID: String
    let senderName: String
    let isOwn: Bool
    let date: Date
    let body: TimelineItemBody
    let replyTo: ReplyPreview?
    let reactions: [ReactionSummary]
    let isEdited: Bool
    let sendState: SendState
    let canBeRepliedTo: Bool
}

enum TimelineItemBody: Equatable {
    case text(AttributedString)
    case emote(AttributedString)
    case notice(AttributedString)
    case image(ImageBody)
    case redacted
    case undecryptable
    case unsupported(String)
}

struct ImageBody: Equatable {
    let caption: String?
    let source: MediaSourceProxy
    let thumbnailSource: MediaSourceProxy?
    /// Width divided by height, when known.
    let aspectRatio: Double?
}

struct ReplyPreview: Equatable {
    let senderName: String
    let text: String
}

struct ReactionSummary: Equatable, Identifiable {
    let key: String
    let count: Int
    let isHighlighted: Bool

    var id: String { key }
}

enum SendState: Equatable {
    case sent
    case sending
    case failed
}

extension EventItem: Identifiable {
    var id: String {
        switch itemID {
        case .eventId(let eventID): eventID
        case .transactionId(let transactionID): transactionID
        }
    }
}
