//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

func messageContent(_ msgType: MessageType, body: String = "", isEdited: Bool = false) -> TimelineItemContent {
    .msgLike(content: MsgLikeContent(kind: .message(content: MessageContent(msgType: msgType, body: body, isEdited: isEdited, mentions: nil)),
                                      inReplyTo: nil,
                                      threadRoot: nil,
                                      threadSummary: nil))
}

func textContent(_ body: String, isEdited: Bool = false) -> TimelineItemContent {
    messageContent(.text(content: TextMessageContent(body: body, formatted: nil)), body: body, isEdited: isEdited)
}

func msgLike(_ kind: MsgLikeKind) -> TimelineItemContent {
    .msgLike(content: MsgLikeContent(kind: kind, inReplyTo: nil, threadRoot: nil, threadSummary: nil))
}

func profile(_ name: String?) -> ProfileDetails {
    .ready(displayName: name, displayNameAmbiguous: false, avatarUrl: nil, status: nil, call: nil)
}

func remoteLatestEvent(_ content: TimelineItemContent,
                        sender: String = "@bob:example.org",
                        name: String? = "Bob",
                        isOwn: Bool = false,
                        timestamp: UInt64 = 1_700_000_000_000) -> LatestEventValue {
    .remote(timestamp: timestamp, sender: sender, isOwn: isOwn, profile: profile(name), content: content)
}
