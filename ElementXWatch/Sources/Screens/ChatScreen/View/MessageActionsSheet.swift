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
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(WatchStrings.quickReactions, id: \.self) { key in
                        Button(key) { onReact(key) }
                            .font(.title3)
                            .buttonStyle(.plain)
                    }
                }
                if item.canBeRepliedTo, item.eventID != nil {
                    Button(WatchStrings.reply, systemImage: "arrowshape.turn.up.left", action: onReply)
                }
            }
        }
    }
}
