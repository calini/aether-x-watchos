//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct RoomRow: View {
    let room: RoomSummary

    var body: some View {
        HStack(spacing: 8) {
            AvatarView(name: room.name, mxcURL: room.avatarURL, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(room.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 4)
                    if let date = room.lastMessageDate {
                        Text(date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                            .font(.caption2)
                            .foregroundStyle(Color.compound.textSecondary)
                    }
                }
                HStack {
                    Text(room.lastMessage ?? " ")
                        .font(.footnote)
                        .foregroundStyle(Color.compound.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if room.hasUnread {
                        Circle()
                            .fill(room.hasUnreadMentions ? Color.compound.iconCriticalPrimary : Color.compound.iconAccentPrimary)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
