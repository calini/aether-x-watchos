//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Testing

struct SessionVerificationMappingTests {
    @Test
    func decimalsMapThrough() {
        #expect(VerificationData(rustData: .decimals(values: [1, 2, 3])) == .decimals([1, 2, 3]))
    }

    @Test
    func emojiIdentityIsSymbolAndDescription() {
        let emoji = VerificationEmoji(symbol: "🐶", description: "Dog")
        #expect(emoji.id == "🐶Dog")
    }
}
