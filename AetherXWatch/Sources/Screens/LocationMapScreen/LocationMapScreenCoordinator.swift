//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MapKit
import SwiftUI

final class LocationMapScreenCoordinator: CoordinatorProtocol {
    private let viewModel: LocationMapScreenViewModel

    init(mode: LocationMapScreenMode, liveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never>?) {
        viewModel = LocationMapScreenViewModel(mode: mode, liveLocationsPublisher: liveLocationsPublisher, openInMaps: Self.openInMaps)
    }

    func toPresentable() -> AnyView {
        AnyView(LocationMapScreen(context: viewModel.context))
    }

    private static func openInMaps(_ geoURI: GeoURI, name: String?) {
        let item: MKMapItem
        if #available(watchOS 26, *) {
            item = MKMapItem(location: CLLocation(latitude: geoURI.latitude, longitude: geoURI.longitude), address: nil)
        } else {
            item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: geoURI.latitude, longitude: geoURI.longitude)))
        }
        item.name = name
        item.openInMaps(launchOptions: nil)
    }
}
