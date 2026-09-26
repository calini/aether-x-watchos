//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Foundation
import Testing

struct LocationMapScreenViewModelTests {
    private let pub = GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: nil)
    private let park = GeoURI(latitude: 51.5073, longitude: -0.1657, uncertainty: nil)

    @Test
    func aOneOffLocationShowsItsCoordinate() {
        let viewModel = LocationMapScreenViewModel(mode: .location(pub, description: "The pub"), liveLocationsPublisher: nil, openInMaps: { _, _ in })

        #expect(viewModel.context.viewState.geoURI == pub)
        #expect(viewModel.context.viewState.title == "The pub")
        #expect(!viewModel.context.viewState.isLive)
        #expect(!viewModel.context.viewState.hasEnded)
    }

    @Test(arguments: [nil, ""])
    func aOneOffLocationWithoutADescriptionIsTitledLocation(description: String?) {
        var opened: [(GeoURI, String?)] = []
        let viewModel = LocationMapScreenViewModel(mode: .location(pub, description: description), liveLocationsPublisher: nil,
                                                   openInMaps: { opened.append(($0, $1)) })

        viewModel.context.send(viewAction: .openInMaps)

        #expect(viewModel.context.viewState.title == WatchStrings.location)
        #expect(opened.first?.1 == nil)
    }

    @Test
    func liveModeFollowsThatUsersUpdates() async throws {
        let shares = CurrentValueSubject<[LiveLocationSummary], Never>([.fixture(userID: "@bob:x", beaconID: "$beacon", geoURI: pub),
                                                                         .fixture(userID: "@alice:x", beaconID: "$beacon", geoURI: park)])
        let viewModel = LocationMapScreenViewModel(mode: .live(userID: "@bob:x", initial: nil), liveLocationsPublisher: shares.eraseToAnyPublisher(), openInMaps: { _, _ in })

        try await waitUntil { viewModel.context.viewState.geoURI == pub }
        #expect(viewModel.context.viewState.isLive)
        #expect(viewModel.context.viewState.title == WatchStrings.liveLocation)

        shares.send([.fixture(userID: "@alice:x", beaconID: "$beacon", geoURI: pub), .fixture(userID: "@bob:x", beaconID: "$beacon", geoURI: park)])

        try await waitUntil { viewModel.context.viewState.geoURI == park }
        #expect(!viewModel.context.viewState.hasEnded)
    }

    @Test
    func liveModeEndsWhenTheUsersShareLeaves() async throws {
        let shares = CurrentValueSubject<[LiveLocationSummary], Never>([.fixture(userID: "@bob:x", beaconID: "$beacon", geoURI: pub)])
        let viewModel = LocationMapScreenViewModel(mode: .live(userID: "@bob:x", initial: nil), liveLocationsPublisher: shares.eraseToAnyPublisher(), openInMaps: { _, _ in })
        try await waitUntil { viewModel.context.viewState.geoURI == pub }

        shares.send([.fixture(userID: "@alice:x", beaconID: "$beacon", geoURI: park)])

        try await waitUntil { viewModel.context.viewState.hasEnded }
        #expect(viewModel.context.viewState.geoURI == pub, "The last known position stays on the map.")
    }

    @Test
    func liveModeStartsFromTheBubblesPositionAndIgnoresTheListBeforeItsFirstUpdate() async throws {
        let shares = CurrentValueSubject<[LiveLocationSummary], Never>([])
        let viewModel = LocationMapScreenViewModel(mode: .live(userID: "@bob:x", initial: pub), liveLocationsPublisher: shares.eraseToAnyPublisher(),
                                                   openInMaps: { _, _ in })
        for _ in 0..<10 { await Task.yield() }

        #expect(viewModel.context.viewState.geoURI == pub)
        #expect(!viewModel.context.viewState.hasEnded)

        shares.send([.fixture(userID: "@bob:x", beaconID: "$beacon", geoURI: park)])

        try await waitUntil { viewModel.context.viewState.geoURI == park }
    }

    @Test
    func liveModeWithoutUpdatesShowsTheBubblesPosition() {
        var opened: [GeoURI] = []
        let viewModel = LocationMapScreenViewModel(mode: .live(userID: "@bob:x", initial: pub), liveLocationsPublisher: nil,
                                                   openInMaps: { geoURI, _ in opened.append(geoURI) })

        viewModel.context.send(viewAction: .openInMaps)

        #expect(viewModel.context.viewState.geoURI == pub)
        #expect(!viewModel.context.viewState.hasEnded)
        #expect(opened == [pub])
    }

    @Test
    func liveModeWithNothingToShowIsEndedRatherThanLoading() {
        let viewModel = LocationMapScreenViewModel(mode: .live(userID: "@bob:x", initial: nil), liveLocationsPublisher: nil, openInMaps: { _, _ in })

        #expect(viewModel.context.viewState.geoURI == nil)
        #expect(viewModel.context.viewState.hasEnded)
    }

    @Test
    func openInMapsUsesTheCurrentCoordinate() async throws {
        var opened: [(GeoURI, String?)] = []
        let shares = CurrentValueSubject<[LiveLocationSummary], Never>([.fixture(userID: "@bob:x", beaconID: "$beacon", geoURI: pub)])
        let viewModel = LocationMapScreenViewModel(mode: .live(userID: "@bob:x", initial: nil), liveLocationsPublisher: shares.eraseToAnyPublisher(),
                                                   openInMaps: { opened.append(($0, $1)) })
        shares.send([.fixture(userID: "@bob:x", beaconID: "$beacon", geoURI: park)])
        try await waitUntil { viewModel.context.viewState.geoURI == park }

        viewModel.context.send(viewAction: .openInMaps)

        #expect(opened.count == 1)
        #expect(opened.first?.0 == park)
        #expect(opened.first?.1 == nil)
    }

    @Test
    func openInMapsPassesTheDescription() {
        var opened: [(GeoURI, String?)] = []
        let viewModel = LocationMapScreenViewModel(mode: .location(pub, description: "The pub"), liveLocationsPublisher: nil,
                                                   openInMaps: { opened.append(($0, $1)) })

        viewModel.context.send(viewAction: .openInMaps)

        #expect(opened.first?.0 == pub)
        #expect(opened.first?.1 == "The pub")
    }
}
