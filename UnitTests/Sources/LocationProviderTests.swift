//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import CoreLocation
@testable import AetherXWatch
import Testing

struct LocationProviderTests {
    @Test
    func authorizationMapsStatuses() {
        #expect(LocationAuthorization(.notDetermined) == .notDetermined)
        #expect(LocationAuthorization(.denied) == .denied)
        #expect(LocationAuthorization(.restricted) == .denied)
        #expect(LocationAuthorization(.authorizedWhenInUse) == .authorized)
        #expect(LocationAuthorization(.authorizedAlways) == .authorized)
    }

    @Test
    func undeterminedAuthorizationTimesOutAtTheUpperBound() async throws {
        let provider = LocationProvider(upperBound: .milliseconds(100))
        // A fresh simulator hasn't been asked yet, and nobody answers the prompt during the test.
        try #require(provider.authorization == .notDetermined)

        let result = await provider.currentLocation(timeout: .seconds(30))

        #expect(result == .failure(.timedOut))
    }

    @Test
    func recentFixUsesAValidRecentLocation() throws {
        let now = Date.now
        let fix = try #require(LocationProvider.recentFix(location(accuracy: 12, age: 30, now: now), now: now))
        #expect(fix == GeoURI(latitude: 51.5, longitude: -0.12, uncertainty: 12))
    }

    @Test
    func recentFixRejectsStaleInvalidOrMissingLocations() {
        let now = Date.now
        #expect(LocationProvider.recentFix(location(accuracy: 12, age: 61, now: now), now: now) == nil)
        #expect(LocationProvider.recentFix(location(accuracy: -1, age: 0, now: now), now: now) == nil)
        #expect(LocationProvider.recentFix(nil, now: now) == nil)
    }

    private func location(accuracy: Double, age: TimeInterval, now: Date) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12),
                   altitude: 0,
                   horizontalAccuracy: accuracy,
                   verticalAccuracy: -1,
                   timestamp: now.addingTimeInterval(-age))
    }
}
