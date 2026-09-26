//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import Testing

struct GeoURITests {
    @Test
    func parsesLatitudeLongitude() throws {
        let uri = try #require(GeoURI(string: "geo:51.5072,-0.1276"))
        #expect(uri.latitude == 51.5072)
        #expect(uri.longitude == -0.1276)
        #expect(uri.uncertainty == nil)
    }

    @Test
    func parsesAltitudeAndParameters() throws {
        let uri = try #require(GeoURI(string: "geo:51.5,-0.12,30;crs=wgs84;u=35"))
        #expect(uri.latitude == 51.5)
        #expect(uri.longitude == -0.12)
        #expect(uri.uncertainty == 35)
    }

    @Test
    func rejectsInvalidInput() {
        #expect(GeoURI(string: "geo:91,0") == nil)
        #expect(GeoURI(string: "geo:0,181") == nil)
        #expect(GeoURI(string: "geo:abc") == nil)
        #expect(GeoURI(string: "https://example.org") == nil)
        #expect(GeoURI(string: "geo:") == nil)
    }

    @Test
    func buildsAString() {
        #expect(GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: 35).string == "geo:51.5072,-0.1276;u=35")
        #expect(GeoURI(latitude: 1, longitude: 2, uncertainty: nil).string == "geo:1.0,2.0")
    }
}
