//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MapKit
import SwiftUI

/// An interactive map: the Crown zooms and dragging pans, both built into `Map`.
struct LocationMapScreen: View {
    private static let regionDistance: CLLocationDistance = 500

    let context: LocationMapScreenViewModel.Context

    var body: some View {
        if let geoURI = context.viewState.geoURI {
            map(initialCoordinate: coordinate(of: geoURI))
        } else if context.viewState.hasEnded {
            Text(WatchStrings.liveLocationEnded)
        } else {
            ProgressView()
        }
    }

    private func map(initialCoordinate: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: initialCoordinate,
                                                        latitudinalMeters: Self.regionDistance,
                                                        longitudinalMeters: Self.regionDistance))) {
            if let geoURI = context.viewState.geoURI {
                Marker(context.viewState.title, coordinate: coordinate(of: geoURI))
                    .tint(context.viewState.hasEnded ? Color.gray : Color.red)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                if context.viewState.hasEnded {
                    Text(WatchStrings.liveLocationEnded)
                        .font(.footnote)
                        .padding(.horizontal, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Button { context.send(viewAction: .openInMaps) } label: {
                    Label(WatchStrings.openInMaps, systemImage: "map")
                }
                .buttonStyle(.fullWidth)
            }
            .padding(.horizontal)
        }
    }

    private func coordinate(of geoURI: GeoURI) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: geoURI.latitude, longitude: geoURI.longitude)
    }
}

// MARK: - Previews

struct LocationMapScreen_Previews: PreviewProvider {
    static let geoURI = GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: nil)
    static let share = LiveLocationSummary(userID: "@bob:x", beaconID: "$beacon", startDate: .now, endDate: .now.addingTimeInterval(900),
                                           lastGeoURI: geoURI, lastUpdate: .now)

    // Kept alive by the previews: a context only weakly references its view model, which owns the subscription.
    static let location = LocationMapScreenViewModel(mode: .location(geoURI, description: "Trafalgar Square"),
                                                     liveLocationsPublisher: nil,
                                                     openInMaps: { _, _ in })
    static let live = makeLiveViewModel([[share]])
    static let liveEnded = makeLiveViewModel([[share], []])
    static let liveWaiting = makeLiveViewModel([])

    static var previews: some View {
        LocationMapScreen(context: location.context)
            .previewDisplayName("Location")
        LocationMapScreen(context: live.context)
            .previewDisplayName("Live")
        LocationMapScreen(context: liveEnded.context)
            .previewDisplayName("Live, ended")
        LocationMapScreen(context: liveWaiting.context)
            .previewDisplayName("Live, waiting")
    }

    static func makeLiveViewModel(_ updates: [[LiveLocationSummary]]) -> LocationMapScreenViewModel {
        LocationMapScreenViewModel(mode: .live(userID: "@bob:x"),
                                   liveLocationsPublisher: updates.publisher.eraseToAnyPublisher(),
                                   openInMaps: { _, _ in })
    }
}
