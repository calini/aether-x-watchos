//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// A tinted capsule button that spans the full width, like the text fields above it.
/// The system button styles cap their width on watchOS, so they end short of the screen edge.
struct FullWidthButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.tint.opacity(0.25), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == FullWidthButtonStyle {
    static var fullWidth: FullWidthButtonStyle { FullWidthButtonStyle() }
}
