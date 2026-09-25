//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import CompoundDesignTokens
import SwiftUI

extension Color {
    /// Compound semantic colour tokens, e.g. `Color.compound.textPrimary`.
    static let compound = CompoundColorTokens()
}

extension Image {
    /// A Compound icon, e.g. `Image(compound: \.send)`.
    init(compound keyPath: KeyPath<CompoundIcons, Image>) {
        self = Self.compoundIcons[keyPath: keyPath]
    }

    private static let compoundIcons = CompoundIcons()
}
