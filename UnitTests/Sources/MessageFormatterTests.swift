//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Foundation
import MatrixRustSDK
import Testing

struct MessageFormatterTests {
    @Test
    func plainTextIsUnchanged() {
        #expect(String(MessageFormatter.attributedString(from: "hello there", formatted: nil).characters) == "hello there")
    }

    @Test
    func plainTextKeepsMarkdownCharacters() {
        let result = MessageFormatter.attributedString(from: "2*3*4", formatted: nil)
        #expect(String(result.characters) == "2*3*4")
        #expect(!result.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
    }

    @Test
    func markdownEmphasisIsRendered() {
        let result = MessageFormatter.attributedString(from: "a **bold** move",
                                                         formatted: FormattedBody(format: .html, body: "a <strong>bold</strong> move"))
        #expect(String(result.characters) == "a bold move")
        #expect(result.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    @Test
    func bareURLsBecomeLinks() {
        let result = MessageFormatter.attributedString(from: "see https://element.io now", formatted: nil)
        #expect(result.runs.contains { $0.link == URL(string: "https://element.io") })
    }

    @Test
    func newlinesArePreserved() {
        #expect(String(MessageFormatter.attributedString(from: "one\ntwo", formatted: nil).characters) == "one\ntwo")
    }
}
