//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// One-line previews for the chats list, derived from iOS's RoomMessageEventStringBuilder.
enum RoomSummaryPreview {
    static func text(for latestEvent: LatestEventValue, isDirect: Bool) -> String? {
        let sender: String
        let senderProfile: ProfileDetails
        let isOwn: Bool
        let content: TimelineItemContent

        switch latestEvent {
        case .none, .remoteInvite:
            return nil
        case .remote(_, let remoteSender, let remoteIsOwn, let remoteProfile, let remoteContent):
            (sender, isOwn, senderProfile, content) = (remoteSender, remoteIsOwn, remoteProfile, remoteContent)
        case .local(_, let localSender, let localProfile, let localContent, _):
            (sender, isOwn, senderProfile, content) = (localSender, true, localProfile, localContent)
        }

        guard let body = text(for: content) else { return nil }

        if isOwn {
            return "\(WatchStrings.you): \(body)"
        } else if isDirect {
            return body
        } else {
            return "\(displayName(from: senderProfile) ?? sender): \(body)"
        }
    }

    static func date(for latestEvent: LatestEventValue) -> Date? {
        switch latestEvent {
        case .none:
            nil
        case .remote(let timestamp, _, _, _, _), .remoteInvite(let timestamp, _, _), .local(let timestamp, _, _, _, _):
            Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        }
    }

    static func text(for content: TimelineItemContent) -> String? {
        guard case .msgLike(let msgLike) = content else { return nil }

        switch msgLike.kind {
        case .message(let message):
            switch message.msgType {
            case .text(let content): return content.body
            case .emote(let content): return "* \(content.body)"
            case .notice(let content): return content.body
            case .image: return WatchStrings.photo
            case .video: return WatchStrings.video
            case .audio(let content): return content.voice == nil ? WatchStrings.audio : "🎤 \(WatchStrings.voiceMessage)"
            case .file: return WatchStrings.file
            case .location: return "📍 \(WatchStrings.location)"
            case .gallery: return WatchStrings.gallery
            case .other(_, let body): return body
            }
        case .sticker: return WatchStrings.sticker
        case .poll(let question, _, _, _, _, _, _): return "📊 \(question)"
        case .redacted: return WatchStrings.messageDeleted
        case .unableToDecrypt: return WatchStrings.waitingForMessage
        case .liveLocation: return "📍 \(WatchStrings.liveLocation)"
        case .other: return nil
        }
    }

    static func displayName(from profile: ProfileDetails) -> String? {
        if case .ready(let displayName, _, _, _, _) = profile { displayName } else { nil }
    }
}
