//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

enum LocationMapScreenMode: Equatable {
    case location(GeoURI, description: String?)
    /// Follows the user's live share in the room.
    case live(userID: String)
}

struct LocationMapScreenViewState: BindableState {
    /// `nil` until a live share's first position arrives.
    var geoURI: GeoURI?
    var title: String
    var isLive: Bool
    /// The live share stopped or expired; the last position stays on the map.
    var hasEnded: Bool
}

enum LocationMapScreenViewAction {
    case openInMaps
}
