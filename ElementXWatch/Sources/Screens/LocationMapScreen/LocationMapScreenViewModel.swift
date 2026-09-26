//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias LocationMapScreenViewModelType = StateStoreViewModelV2<LocationMapScreenViewState, LocationMapScreenViewAction>

final class LocationMapScreenViewModel: LocationMapScreenViewModelType, LocationMapScreenViewModelProtocol {
    private let description: String?
    private let openInMaps: (GeoURI, String?) -> Void

    init(mode: LocationMapScreenMode, liveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never>?, openInMaps: @escaping (GeoURI, String?) -> Void) {
        self.openInMaps = openInMaps

        switch mode {
        case .location(let geoURI, let description):
            let description = description?.isEmpty == false ? description : nil
            self.description = description
            super.init(initialViewState: LocationMapScreenViewState(geoURI: geoURI, title: description ?? WatchStrings.location,
                                                                    isLive: false, hasEnded: false))
        case .live(let userID, let initial):
            description = nil
            // Without updates or a position there is nothing to wait for, so it shows as ended rather than loading forever.
            let hasEnded = liveLocationsPublisher == nil && initial == nil
            super.init(initialViewState: LocationMapScreenViewState(geoURI: initial, title: WatchStrings.liveLocation, isLive: true, hasEnded: hasEnded))

            liveLocationsPublisher?
                // The room's list starts empty before its first update, which would read as ended.
                .drop { $0.isEmpty }
                .map { summaries in summaries.first { $0.userID == userID } }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] summary in self?.update(summary) }
                .store(in: &cancellables)
        }
    }

    override func process(viewAction: LocationMapScreenViewAction) {
        switch viewAction {
        case .openInMaps:
            guard let geoURI = state.geoURI else { return }
            openInMaps(geoURI, description)
        }
    }

    private func update(_ summary: LiveLocationSummary?) {
        state.hasEnded = summary == nil
        if let geoURI = summary?.lastGeoURI {
            state.geoURI = geoURI
        }
    }
}
