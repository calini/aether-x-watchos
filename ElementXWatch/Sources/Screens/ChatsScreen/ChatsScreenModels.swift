//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

enum ChatsScreenViewModelAction {
    case openRoom(RoomSummary)
    case openSettings
}

struct ChatsScreenViewState: BindableState {
    var rooms: [RoomSummary] = []
    var syncState: SyncState = .idle
    var isLoading = true
}

enum ChatsScreenViewAction {
    case selectRoom(String)
    case openSettings
}
