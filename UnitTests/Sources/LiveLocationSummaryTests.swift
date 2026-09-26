//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

struct LiveLocationSummaryTests {
    @Test
    func mapsAShare() {
        let summary = LiveLocationSummaries.summary(from: share("@a:x", lat: 51.5, startTs: 1_700_000_000_000, locationTs: 1_700_000_010_000))

        #expect(summary == LiveLocationSummary(userID: "@a:x",
                                               beaconID: "$beacon-@a:x",
                                               startDate: Date(timeIntervalSince1970: 1_700_000_000),
                                               endDate: Date(timeIntervalSince1970: 1_700_000_900),
                                               lastGeoURI: GeoURI(latitude: 51.5, longitude: -0.12, uncertainty: nil),
                                               lastUpdate: Date(timeIntervalSince1970: 1_700_000_010)))
        #expect(summary.id == "@a:x")
    }

    @Test
    func mapsTheEndDateFromTheStartAndTimeout() {
        let share = LiveLocationShare(lastLocation: nil, userId: "@a:x", startTs: 1_700_000_000_500, timeout: 3_600_000, beaconId: "$beacon")

        #expect(LiveLocationSummaries.summary(from: share).endDate == Date(timeIntervalSince1970: 1_700_003_600.5))
    }

    @Test
    func saturatesAnOverflowingTimeout() {
        let share = LiveLocationShare(lastLocation: nil, userId: "@a:x", startTs: 1_700_000_000_000, timeout: .max, beaconId: "$beacon")

        #expect(LiveLocationSummaries.summary(from: share).endDate == Date(timeIntervalSince1970: TimeInterval(UInt64.max) / 1000))
    }

    @Test
    func mapsAShareWithoutALocationYet() {
        let share = LiveLocationShare(lastLocation: nil, userId: "@a:x", startTs: 1_700_000_000_000, timeout: 60000, beaconId: "$beacon")
        let summary = LiveLocationSummaries.summary(from: share)

        #expect(summary.lastGeoURI == nil)
        #expect(summary.lastUpdate == nil)
    }

    @Test
    func keepsAnInvalidGeoURIAsNoLocation() {
        let location = LastLocation(location: LocationContent(body: "", geoUri: "geo:abc", description: nil, zoomLevel: nil, asset: .sender), ts: 1)
        let share = LiveLocationShare(lastLocation: location, userId: "@a:x", startTs: 0, timeout: 60000, beaconId: "$beacon")

        #expect(LiveLocationSummaries.summary(from: share).lastGeoURI == nil)
        #expect(LiveLocationSummaries.summary(from: share).lastUpdate == Date(timeIntervalSince1970: 0.001))
    }

    @Test
    func appliesDiffs() {
        let a = share("@a:x", lat: 1), b = share("@b:x", lat: 2)
        var summaries = LiveLocationSummaries.apply([.append(values: [a, b])], to: [])
        #expect(summaries.map(\.userID) == ["@a:x", "@b:x"])

        summaries = LiveLocationSummaries.apply([.set(index: 1, value: share("@b:x", lat: 3)), .remove(index: 0)], to: summaries)
        #expect(summaries.map(\.userID) == ["@b:x"])
        #expect(summaries.first?.lastGeoURI?.latitude == 3)
    }

    @Test
    func appliesPushesAndInserts() {
        var summaries = LiveLocationSummaries.apply([.pushBack(value: share("@b:x", lat: 2)),
                                                     .pushFront(value: share("@a:x", lat: 1)),
                                                     .insert(index: 1, value: share("@c:x", lat: 3))], to: [])
        #expect(summaries.map(\.userID) == ["@a:x", "@c:x", "@b:x"])

        summaries = LiveLocationSummaries.apply([.popFront, .popBack], to: summaries)
        #expect(summaries.map(\.userID) == ["@c:x"])
    }

    @Test
    func appliesClearResetAndTruncate() {
        var summaries = LiveLocationSummaries.apply([.reset(values: [share("@a:x", lat: 1), share("@b:x", lat: 2)])], to: [])
        #expect(summaries.map(\.userID) == ["@a:x", "@b:x"])

        summaries = LiveLocationSummaries.apply([.truncate(length: 1)], to: summaries)
        #expect(summaries.map(\.userID) == ["@a:x"])

        summaries = LiveLocationSummaries.apply([.clear], to: summaries)
        #expect(summaries.isEmpty)
    }

    @Test
    func ignoresOutOfRangeIndices() {
        let summaries = LiveLocationSummaries.apply([.set(index: 5, value: share("@b:x", lat: 2)), .remove(index: 3)],
                                                    to: [LiveLocationSummaries.summary(from: share("@a:x", lat: 1))])
        #expect(summaries.map(\.userID) == ["@a:x"])
    }

    // MARK: - Helpers

    private func share(_ userID: String, lat: Double, startTs: UInt64 = 1_700_000_000_000, locationTs: UInt64 = 1_700_000_010_000) -> LiveLocationShare {
        let content = LocationContent(body: "Location", geoUri: "geo:\(lat),-0.12", description: nil, zoomLevel: nil, asset: .sender)
        return LiveLocationShare(lastLocation: LastLocation(location: content, ts: locationTs),
                                 userId: userID, startTs: startTs, timeout: 900_000, beaconId: "$beacon-\(userID)")
    }
}
