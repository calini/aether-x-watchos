//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import Foundation
import Testing

struct MessageFormatterTests {
    @Test
    func plainTextIsUnchanged() {
        #expect(String(MessageFormatter.attributedString(from: "hello there").characters) == "hello there")
    }

    @Test
    func markdownEmphasisIsRendered() {
        let result = MessageFormatter.attributedString(from: "a **bold** move")
        #expect(String(result.characters) == "a bold move")
        #expect(result.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    @Test
    func bareURLsBecomeLinks() {
        let result = MessageFormatter.attributedString(from: "see https://element.io now")
        #expect(result.runs.contains { $0.link == URL(string: "https://element.io") })
    }

    @Test
    func newlinesArePreserved() {
        #expect(String(MessageFormatter.attributedString(from: "one\ntwo").characters) == "one\ntwo")
    }
}
