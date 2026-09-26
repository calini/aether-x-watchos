//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import Testing

struct StringEmojiTests {
    @Test(arguments: [
        ("👍", "👍"),
        ("nice 👍🏽 thanks", "👍🏽"),
        ("👨‍👩‍👧 family", "👨‍👩‍👧"),
        ("🇬🇧", "🇬🇧"),
        ("1️⃣ first", "1️⃣"),
        ("❤️", "❤️"),
        ("☝🏽", "☝🏽"),
        ("🏳️‍🌈", "🏳️‍🌈"),
        ("abc 😂 🙏", "😂")
    ])
    func findsTheFirstEmoji(text: String, emoji: String) {
        #expect(text.firstEmoji == emoji)
    }

    @Test(arguments: ["", "hello", "123", "#1 *", "©", "é"])
    func ignoresTextWithoutEmoji(text: String) {
        #expect(text.firstEmoji == nil)
    }
}
