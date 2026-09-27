//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// A round icon button: Liquid Glass on watchOS 26, a subtle filled circle before that.
struct CircleGlassButtonStyle: ButtonStyle {
    let size: CGFloat
    var iconColor = Color.compound.iconPrimary

    func makeBody(configuration: Configuration) -> some View {
        if #available(watchOS 26, *) {
            label(configuration)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            label(configuration)
                .background(Color.compound.bgSubtleSecondary, in: Circle())
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }

    private func label(_ configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(iconColor)
            .frame(width: size, height: size)
            .contentShape(Circle())
    }
}
