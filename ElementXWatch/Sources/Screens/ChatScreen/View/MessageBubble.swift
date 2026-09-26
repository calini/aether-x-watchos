//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct MessageBubble: View {
    let item: EventItem
    let showsSenderName: Bool
    /// A live share merged with the room's latest data (`ChatScreenViewState.liveLocation(for:)`); `nil` for other messages.
    let liveLocation: LiveLocationBubbleState?
    let onLongPress: () -> Void
    let onRetry: () -> Void
    let onShowLocation: () -> Void
    /// Set on the user's own running live share, to offer Stop.
    var onStopLiveLocation: (() -> Void)?

    var body: some View {
        VStack(alignment: item.isOwn ? .trailing : .leading, spacing: 2) {
            if showsSenderName, !item.isOwn {
                Text(item.senderName).font(.caption2).foregroundStyle(Color.compound.textSecondary)
            }
            bubble
                .onLongPressGesture(perform: onLongPress)
                .onTapGesture { if item.sendState == .failed { onRetry() } }
            if !item.reactions.isEmpty {
                ReactionsBar(reactions: item.reactions)
            }
            status
        }
        .frame(maxWidth: .infinity, alignment: item.isOwn ? .trailing : .leading)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let reply = item.replyTo {
                VStack(alignment: .leading) {
                    Text(reply.senderName).font(.caption2.bold()).foregroundStyle(Color.compound.textPrimary)
                    Text(reply.text).font(.caption2).lineLimit(2).foregroundStyle(Color.compound.textSecondary)
                }
                .padding(4)
                .background(Color.compound.bgCanvasDefault, in: RoundedRectangle(cornerRadius: 6))
            }
            content
        }
        .padding(8)
        .background(item.isOwn ? Color.compound.bgBubbleOutgoing : Color.compound.bgBubbleIncoming,
                    in: RoundedRectangle(cornerRadius: 12))
        .opacity(item.sendState == .sent ? 1 : 0.6)
    }

    @ViewBuilder
    private var content: some View {
        switch item.body {
        case .text(let text), .notice(let text):
            Text(text).font(.body)
        case .emote(let text):
            Text("* \(item.senderName) ").italic() + Text(text).italic()
        case .image(let image):
            ImageThumbnail(image: image)
        case .location(let location):
            LocationBubble(content: .location(location), onTap: onShowLocation)
        case .liveLocation:
            if let liveLocation {
                LocationBubble(content: .live(liveLocation), onTap: onShowLocation, onStop: onStopLiveLocation)
            }
        case .redacted:
            Text(WatchStrings.messageDeleted).italic().foregroundStyle(Color.compound.textSecondary)
        case .undecryptable:
            Text(WatchStrings.waitingForMessage).italic().foregroundStyle(Color.compound.textSecondary)
        case .unsupported(let description):
            Text(description).foregroundStyle(Color.compound.textSecondary)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch item.sendState {
        case .failed:
            Text(WatchStrings.failedTapToRetry).font(.caption2).foregroundStyle(Color.compound.textCriticalPrimary)
        case .sending:
            Text(WatchStrings.sending).font(.caption2).foregroundStyle(Color.compound.textSecondary)
        case .sent:
            if item.isEdited {
                Text(WatchStrings.edited).font(.caption2).foregroundStyle(Color.compound.textSecondary)
            }
        }
    }
}
