//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Renders message bodies: inline Markdown (bold, italic, code, links) plus auto-linked URLs.
enum MessageFormatter {
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func attributedString(from body: String) -> AttributedString {
        var result = (try? AttributedString(markdown: body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(body)
        addLinks(to: &result)
        return result
    }

    private static func addLinks(to string: inout AttributedString) {
        guard let linkDetector else { return }
        let plain = String(string.characters)
        for match in linkDetector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: plain),
                  let range = Range(stringRange, in: string),
                  string[range].link == nil else { continue }
            string[range].link = url
        }
    }
}
