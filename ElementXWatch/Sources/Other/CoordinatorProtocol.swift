//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

protocol CoordinatorProtocol: AnyObject {
    func start()
    func stop()
    func toPresentable() -> AnyView
}

extension CoordinatorProtocol {
    func start() { }

    func stop() { }

    func toPresentable() -> AnyView {
        AnyView(Text("View not configured"))
    }
}
