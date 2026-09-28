//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// Renders message bodies: inline Markdown (bold, italic, code, links) plus auto-linked URLs.
enum MessageFormatter {
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// `formatted` is non-nil only when the sender actually used formatting; parsing plain text as
    /// Markdown would otherwise mangle stray characters (e.g. `2*3*4` loses its asterisks).
    static func attributedString(from body: String, formatted: FormattedBody?) -> AttributedString {
        var result = if formatted != nil {
            (try? AttributedString(markdown: body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                ?? AttributedString(body)
        } else {
            AttributedString(body)
        }
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
