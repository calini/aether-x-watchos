//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import MatrixRustSDK

/// A live room list entries stream. Updates stop once it's released.
protocol RoomListEntriesSubscriptionProtocol: AnyObject {
    func setFilter(_ kind: RoomListEntriesDynamicFilterKind)
}

/// Owns everything `RoomList.entriesWithDynamicAdapters` hands back, as one unit.
final class RoomListEntriesSubscription: RoomListEntriesSubscriptionProtocol {
    /// Owns the `RoomList` the Rust entries task borrows: releasing it while `entriesHandle` runs is a use-after-free.
    // periphery:ignore - retaining purpose
    private let result: RoomListEntriesWithDynamicAdaptersResult
    private let controller: RoomListDynamicEntriesController
    private let entriesHandle: TaskHandle

    init(_ result: RoomListEntriesWithDynamicAdaptersResult) {
        self.result = result
        controller = result.controller()
        entriesHandle = result.entriesStream()
    }

    deinit {
        // Aborts the task before `result` releases the `RoomList` it borrows.
        entriesHandle.cancel()
    }

    func setFilter(_ kind: RoomListEntriesDynamicFilterKind) {
        _ = controller.setFilter(kind: kind)
    }
}
