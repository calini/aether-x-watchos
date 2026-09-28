//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

/// A session's location services: one provider and one live share, shared by all its chats.
struct LocationServices {
    let locationProvider: LocationProviderProtocol
    let liveLocationService: LiveLocationServiceProtocol

    static func live(for clientProxy: ClientProxyProtocol) -> LocationServices {
        let locationProvider = LocationProvider()
        let liveLocationService = LiveLocationService(ownUserID: clientProxy.userID,
                                                      locationProvider: locationProvider,
                                                      roomProvider: { await clientProxy.roomLocationProxy(for: $0) },
                                                      ownBeaconInfoPublisher: clientProxy.ownBeaconInfoPublisher,
                                                      store: UserDefaultsLiveLocationShareStore(userID: clientProxy.userID))
        return LocationServices(locationProvider: locationProvider, liveLocationService: liveLocationService)
    }
}
