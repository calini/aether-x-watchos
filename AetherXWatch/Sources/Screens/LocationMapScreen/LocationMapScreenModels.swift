//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum LocationMapScreenMode: Equatable {
    case location(GeoURI, description: String?)
    /// Follows the user's live share in the room, starting from the position the bubble already has.
    /// `endDate` ends it on time if no update or stop arrives, e.g. when the sender's device died.
    case live(userID: String, initial: GeoURI?, endDate: Date?)
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
