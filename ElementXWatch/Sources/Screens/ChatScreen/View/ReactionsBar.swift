//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct ReactionsBar: View {
    let reactions: [ReactionSummary]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions) { reaction in
                Text("\(reaction.key) \(reaction.count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(reaction.isHighlighted ? Color.compound.bgAccentRest.opacity(0.4) : Color.compound.bgSubtleSecondary,
                                in: Capsule())
            }
        }
    }
}
