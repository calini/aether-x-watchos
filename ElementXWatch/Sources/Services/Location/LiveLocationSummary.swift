//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

/// One user's active live location share in a room.
struct LiveLocationSummary: Equatable, Identifiable {
    let userID: String
    /// The `beacon_info` event ID of the share.
    let beaconID: String
    let startDate: Date
    /// When the share stops being live: its start plus its timeout.
    let endDate: Date
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
                            beaconID: share.beaconId,
                            startDate: date(fromMilliseconds: share.startTs),
                            endDate: date(fromMilliseconds: endMilliseconds(of: share)),
                            lastGeoURI: share.lastLocation.flatMap { GeoURI(string: $0.location.geoUri) },
                            lastUpdate: share.lastLocation.map { date(fromMilliseconds: $0.ts) })
    }

    /// Saturates: the timeout comes from other people's events, and an overflowing `+` would trap.
    private static func endMilliseconds(of share: LiveLocationShare) -> UInt64 {
        let (end, didOverflow) = share.startTs.addingReportingOverflow(share.timeout)
        return didOverflow ? .max : end
    }

    private static func date(fromMilliseconds milliseconds: UInt64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

enum LiveLocationExpiry {
    /// How often an open screen re-checks its live shares' end times: a share whose sender's device died never gets a stop event.
    static var ticks: AnyPublisher<Void, Never> {
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .map { _ in }
            .eraseToAnyPublisher()
    }
}
