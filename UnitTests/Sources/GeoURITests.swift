//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Foundation
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
        #expect(GeoURI(latitude: 1, longitude: 2, uncertainty: nil).string == "geo:1,2")
    }

    @Test
    func buildsFixedPointStringsForTinyValues() {
        // Plain interpolation would print "-5e-05", which isn't a valid geo URI.
        #expect(GeoURI(latitude: 51.4779, longitude: -0.00005, uncertainty: nil).string == "geo:51.4779,-0.00005")
        #expect(GeoURI(latitude: 0.0000004, longitude: -0.0000004, uncertainty: nil).string == "geo:0,0")
        #expect(GeoURI(latitude: -0.000123, longitude: 0.00001, uncertainty: 5).string == "geo:-0.000123,0.00001;u=5")
    }

    @Test
    func roundsToSixDecimals() {
        #expect(GeoURI(latitude: -33.123456789, longitude: 151.9999999, uncertainty: nil).string == "geo:-33.123457,152")
    }

    @Test
    func locationMessagesFallBackToTheGeoURI() {
        let geoURI = GeoURI(latitude: 51.5, longitude: -0.00005, uncertainty: 10)
        #expect(WatchStrings.locationWasShared(at: geoURI.string) == "Location was shared at geo:51.5,-0.00005;u=10")
    }

    @Test
    func buildsTheSameStringInANonEnglishLocale() throws {
        let previous = String(cString: setlocale(LC_NUMERIC, nil))
        defer { setlocale(LC_NUMERIC, previous) }
        try #require(setlocale(LC_NUMERIC, "fr_FR.UTF-8") != nil)
        // Proves the locale took: C formatting now uses a decimal comma.
        try #require(String(cString: localeconv().pointee.decimal_point) == ",")

        #expect(GeoURI(latitude: 48.8566, longitude: -0.00005, uncertainty: 12).string == "geo:48.8566,-0.00005;u=12")
    }
}
