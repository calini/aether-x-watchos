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
    private let now: () -> Date
    /// The share left the room's list, or there was never anything to follow.
    private var isShareGone = false
    private var endDate: Date?

    /// - Parameter ticks: Re-evaluates a live share's expiry; `now` gives the time at each tick.
    init(mode: LocationMapScreenMode,
         liveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never>?,
         openInMaps: @escaping (GeoURI, String?) -> Void,
         now: @escaping () -> Date = Date.init,
         ticks: AnyPublisher<Void, Never> = LiveLocationExpiry.ticks) {
        self.openInMaps = openInMaps
        self.now = now

        switch mode {
        case .location(let geoURI, let description):
            let description = description?.isEmpty == false ? description : nil
            self.description = description
            super.init(initialViewState: LocationMapScreenViewState(geoURI: geoURI, title: description ?? WatchStrings.location,
                                                                    isLive: false, hasEnded: false))
        case .live(let userID, let initial, let endDate):
            description = nil
            self.endDate = endDate
            // Without updates or a position there is nothing to wait for, so it shows as ended rather than loading forever.
            isShareGone = liveLocationsPublisher == nil && initial == nil
            super.init(initialViewState: LocationMapScreenViewState(geoURI: initial, title: WatchStrings.liveLocation, isLive: true, hasEnded: false))
            refreshHasEnded()

            liveLocationsPublisher?
                // The room's list starts empty before its first update, which would read as ended.
                .drop { $0.isEmpty }
                .map { summaries in summaries.first { $0.userID == userID } }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] summary in self?.update(summary) }
                .store(in: &cancellables)

            ticks
                .sink { [weak self] in self?.refreshHasEnded() }
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
        isShareGone = summary == nil
        if let summary {
            endDate = summary.endDate
        }
        if let geoURI = summary?.lastGeoURI {
            state.geoURI = geoURI
        }
        refreshHasEnded()
    }

    private func refreshHasEnded() {
        let hasExpired = endDate.map { now() >= $0 } ?? false
        state.hasEnded = isShareGone || hasExpired
    }
}
