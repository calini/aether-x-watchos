//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct MessageActionsSheet: View {
    let item: EventItem
    let onReact: (String) -> Void
    let onReply: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    quickReactions
                    if item.canBeRepliedTo, item.eventID != nil {
                        Button(WatchStrings.reply, systemImage: "arrowshape.turn.up.left.fill", action: onReply)
                            .buttonStyle(.fullWidth)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    moreReactionsButton
                }
            }
        }
    }

    private var quickReactions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 8) {
            ForEach(WatchStrings.quickReactions, id: \.self) { key in
                Button { onReact(key) } label: {
                    Text(key)
                        .font(.title)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// watchOS has no emoji picker API, but the system text input offers one.
    private var moreReactionsButton: some View {
        TextFieldLink(prompt: Text(WatchStrings.moreReactions)) {
            Label(WatchStrings.moreReactions, systemImage: "face.smiling")
        } onSubmit: { text in
            if let emoji = text.firstEmoji { onReact(emoji) }
        }
    }
}

// MARK: - Previews

struct MessageActionsSheet_Previews: PreviewProvider {
    static var previews: some View {
        MessageActionsSheet(item: makeItem(canBeRepliedTo: true), onReact: { _ in }, onReply: { })
            .previewDisplayName("Replyable")
        MessageActionsSheet(item: makeItem(canBeRepliedTo: false), onReact: { _ in }, onReply: { })
            .previewDisplayName("Reactions only")
    }

    static func makeItem(canBeRepliedTo: Bool) -> EventItem {
        EventItem(itemID: .eventId(eventId: "$1"), eventID: "$1", senderID: "@bob:x", senderName: "Bob", isOwn: false, date: .now,
                  body: .text(AttributedString("Are we still on for Saturday?")), replyTo: nil, reactions: [],
                  isEdited: false, sendState: .sent, canBeRepliedTo: canBeRepliedTo)
    }
}
