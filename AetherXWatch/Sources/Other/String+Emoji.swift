//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

nonisolated extension String {
    /// The first emoji in the string, including multi-scalar ones (skin tones, ZWJ families, flags, keycaps).
    var firstEmoji: String? {
        first(where: \.isEmoji).map(String.init)
    }
}

nonisolated extension Character {
    /// Digits, `#` and `*` count as emoji in Unicode, so text-default scalars only qualify when
    /// followed by an emoji variation selector, keycap or skin tone.
    var isEmoji: Bool {
        guard let first = unicodeScalars.first, first.properties.isEmoji else { return false }
        return first.properties.isEmojiPresentation || unicodeScalars.dropFirst().contains {
            $0 == "\u{FE0F}" || $0 == "\u{20E3}" || $0.properties.isEmojiModifier
        }
    }
}
