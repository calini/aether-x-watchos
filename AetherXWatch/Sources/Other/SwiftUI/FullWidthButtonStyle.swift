//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// A capsule button that spans the full width, like the text fields above it: Liquid Glass on
/// watchOS 26, a tinted capsule before that. The system button styles (`.glass` included) cap
/// their width on watchOS, so they end short of the screen edge.
struct FullWidthButtonStyle: ButtonStyle {
    /// Tints the glass with the accent colour, for a screen's primary action.
    let isProminent: Bool

    @Environment(\.isEnabled) private var isEnabled

    @available(watchOS 26, *)
    private var glass: Glass {
        (isProminent ? Glass.regular.tint(Color.compound.bgAccentRest) : .regular)
            .interactive(isEnabled)
    }

    func makeBody(configuration: Configuration) -> some View {
        if #available(watchOS 26, *) {
            label(configuration)
                .foregroundStyle(isProminent ? Color.compound.textOnSolidPrimary : Color.compound.textPrimary)
                .glassEffect(glass, in: .capsule)
                .opacity(isEnabled ? 1 : 0.4)
        } else {
            label(configuration)
                .foregroundStyle(Color.compound.bgAccentRest)
                .background(Color.compound.bgAccentRest.opacity(0.25), in: Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
        }
    }

    private func label(_ configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == FullWidthButtonStyle {
    /// Plain glass, for secondary actions such as Reply.
    static var fullWidth: FullWidthButtonStyle { FullWidthButtonStyle(isProminent: false) }
    /// Accent-tinted glass, for a screen's primary action.
    static var fullWidthProminent: FullWidthButtonStyle { FullWidthButtonStyle(isProminent: true) }
}
