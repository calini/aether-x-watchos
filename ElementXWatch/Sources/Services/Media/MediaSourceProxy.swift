//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import MatrixRustSDK

/// A hashable wrapper around the SDK's `MediaSource` (a class without value semantics).
struct MediaSourceProxy: Hashable {
    let source: MediaSource
    let url: String

    init(source: MediaSource) {
        self.source = source
        url = source.url()
    }

    static func == (lhs: MediaSourceProxy, rhs: MediaSourceProxy) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
