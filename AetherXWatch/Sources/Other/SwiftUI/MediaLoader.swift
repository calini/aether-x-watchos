//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// Loads media for views without handing them the whole client.
struct MediaLoader {
    let loadThumbnail: (MediaSourceProxy, Int, Int) async -> Data?
    /// Fetches the whole original file, e.g. for a full-screen viewer that needs more detail than a thumbnail.
    let loadContent: (MediaSourceProxy) async -> Data?
}

extension EnvironmentValues {
    @Entry var mediaLoader = MediaLoader(loadThumbnail: { _, _, _ in nil }, loadContent: { _ in nil })
}
