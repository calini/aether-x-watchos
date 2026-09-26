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

struct TimelineItemFactoryLocationTests {
    @Test
    func mapsALocationMessage() {
        let content = LocationContent(body: "Location", geoUri: "geo:51.5,-0.12;u=10", description: "Home", zoomLevel: nil, asset: .sender)
        let body = TimelineItemFactory.locationBody(from: content)
        #expect(body == LocationBody(geoURI: GeoURI(latitude: 51.5, longitude: -0.12, uncertainty: 10), description: "Home", body: "Location"))
    }

    @Test
    func keepsAnInvalidLocationAsAPlaceholder() {
        let content = LocationContent(body: "Location", geoUri: "geo:abc", description: nil, zoomLevel: nil, asset: .sender)
        #expect(TimelineItemFactory.locationBody(from: content).geoURI == nil)
    }

    @Test
    func mapsALiveLocationWithUpdates() {
        let content = LiveLocationContent(isLive: true, ts: 1_700_000_000_000, description: nil, timeoutMs: 60_000, assetType: .sender,
                                           locations: [BeaconInfo(geoUri: "geo:51.5,-0.12", ts: 1_700_000_000_000, description: nil),
                                                       BeaconInfo(geoUri: "geo:51.6,-0.13", ts: 1_700_000_010_000, description: nil)])

        let body = TimelineItemFactory.liveLocationBody(from: content, senderID: "@bob:example.org")

        #expect(body == LiveLocationBody(isLive: true,
                                          lastGeoURI: GeoURI(latitude: 51.6, longitude: -0.13, uncertainty: nil),
                                          lastUpdate: Date(timeIntervalSince1970: 1_700_000_010),
                                          endDate: Date(timeIntervalSince1970: 1_700_000_060),
                                          senderID: "@bob:example.org"))
    }

    @Test
    func mapsALiveLocationWithNoUpdatesYet() {
        let content = LiveLocationContent(isLive: true, ts: 1_700_000_000_000, description: nil, timeoutMs: 60_000, assetType: .sender, locations: [])

        let body = TimelineItemFactory.liveLocationBody(from: content, senderID: "@bob:example.org")

        #expect(body == LiveLocationBody(isLive: true, lastGeoURI: nil, lastUpdate: nil,
                                          endDate: Date(timeIntervalSince1970: 1_700_000_060), senderID: "@bob:example.org"))
    }

    @Test
    func mapsAnEndedLiveLocation() {
        let content = LiveLocationContent(isLive: false, ts: 1_700_000_000_000, description: nil, timeoutMs: 60_000, assetType: .sender,
                                           locations: [BeaconInfo(geoUri: "geo:51.5,-0.12", ts: 1_700_000_000_000, description: nil)])

        #expect(TimelineItemFactory.liveLocationBody(from: content, senderID: "@bob:example.org").isLive == false)
    }

    @Test
    func anOverflowingTimeoutNeverEnds() {
        let content = LiveLocationContent(isLive: true, ts: 1_700_000_000_000, description: nil, timeoutMs: .max, assetType: .sender, locations: [])

        #expect(TimelineItemFactory.liveLocationBody(from: content, senderID: "@bob:example.org").endDate == .distantFuture)
    }
}
