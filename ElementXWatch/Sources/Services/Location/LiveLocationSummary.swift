//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// One user's active live location share in a room.
struct LiveLocationSummary: Equatable, Identifiable {
    let userID: String
    let startDate: Date
    let lastGeoURI: GeoURI?
    let lastUpdate: Date?

    var id: String { userID }
}

enum LiveLocationSummaries {
    /// Applies one SDK diff batch to the summaries, in order.
    static func apply(_ updates: [LiveLocationShareUpdate], to summaries: [LiveLocationSummary]) -> [LiveLocationSummary] {
        var summaries = summaries
        for update in updates {
            summaries.apply(ListDiff(update, transform: summary(from:)))
        }
        return summaries
    }

    static func summary(from share: LiveLocationShare) -> LiveLocationSummary {
        LiveLocationSummary(userID: share.userId,
                            startDate: date(fromMilliseconds: share.startTs),
                            lastGeoURI: share.lastLocation.flatMap { GeoURI(string: $0.location.geoUri) },
                            lastUpdate: share.lastLocation.map { date(fromMilliseconds: $0.ts) })
    }

    private static func date(fromMilliseconds milliseconds: UInt64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
