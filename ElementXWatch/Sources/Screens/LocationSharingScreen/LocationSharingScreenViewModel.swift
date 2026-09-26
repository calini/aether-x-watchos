//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias LocationSharingScreenViewModelType = StateStoreViewModelV2<LocationSharingScreenViewState, LocationSharingScreenViewAction>

final class LocationSharingScreenViewModel: LocationSharingScreenViewModelType, LocationSharingScreenViewModelProtocol {
    static let locateTimeout: Duration = .seconds(30)
    static let snapshotSize = CGSize(width: 180, height: 100)

    private let roomID: String
    private let roomName: (String) -> String?
    private let locationProvider: LocationProviderProtocol
    private let liveLocationService: LiveLocationServiceProtocol
    private let sendLocation: (GeoURI) async -> Result<Void, TimelineProxyError>
    private let snapshotLoader: MapSnapshotLoaderProtocol?
    private let actionsSubject = PassthroughSubject<LocationSharingScreenViewModelAction, Never>()
    private var hasAppeared = false
    /// Kept apart from the alert's binding, which the alert may clear before its button's action runs.
    private var pendingReplace: LiveShareDuration?

    var actionsPublisher: AnyPublisher<LocationSharingScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    /// - Parameter roomName: Names another room for the replace confirmation, `nil` if unknown.
    init(roomID: String,
         roomName: @escaping (String) -> String?,
         locationProvider: LocationProviderProtocol,
         liveLocationService: LiveLocationServiceProtocol,
         sendLocation: @escaping (GeoURI) async -> Result<Void, TimelineProxyError>,
         snapshotLoader: MapSnapshotLoaderProtocol?) {
        self.roomID = roomID
        self.roomName = roomName
        self.locationProvider = locationProvider
        self.liveLocationService = liveLocationService
        self.sendLocation = sendLocation
        self.snapshotLoader = snapshotLoader
        super.init(initialViewState: LocationSharingScreenViewState(authorization: locationProvider.authorization))

        // Follows the first-use prompt, so the sheet reflects the answer. Not hopped via the main queue:
        // the provider publishes on the main actor, and a late replay could undo a denial seen meanwhile.
        locationProvider.authorizationPublisher
            .sink { [weak self] authorization in self?.state.authorization = authorization }
            .store(in: &cancellables)
    }

    override func process(viewAction: LocationSharingScreenViewAction) {
        switch viewAction {
        case .appear:
            guard !hasAppeared else { return }
            hasAppeared = true
            locate()
        case .tryAgain:
            locate()
        case .sendCurrent:
            sendCurrent()
        case .shareLive(let duration):
            shareLive(duration)
        case .confirmReplace:
            guard let duration = pendingReplace else { return }
            pendingReplace = nil
            state.bindings.confirmReplace = nil
            startLiveShare(duration)
        case .cancelReplace:
            pendingReplace = nil
            state.bindings.confirmReplace = nil
        }
    }

    private func locate() {
        guard state.authorization != .denied, !state.isLocating else { return }
        if state.authorization == .notDetermined {
            locationProvider.requestAuthorization()
        }
        state.isLocating = true
        state.locateFailed = false

        Task {
            // The provider's timeout only starts once permission is granted, so the prompt reads as "Finding your location…".
            let result = await locationProvider.currentLocation(timeout: Self.locateTimeout)
            state.isLocating = false
            switch result {
            case .success(let geoURI):
                state.geoURI = geoURI
                await loadSnapshot(of: geoURI)
            case .failure(.denied):
                state.authorization = .denied
            case .failure:
                state.locateFailed = true
            }
        }
    }

    private func loadSnapshot(of geoURI: GeoURI) async {
        guard let snapshotLoader else {
            state.snapshotFailed = true
            return
        }
        state.snapshot = await snapshotLoader.snapshot(of: geoURI, size: Self.snapshotSize)
        state.snapshotFailed = state.snapshot == nil
    }

    private func sendCurrent() {
        guard state.canSendCurrent, let geoURI = state.geoURI else { return }
        state.isBusy = true
        Task {
            let result = await sendLocation(geoURI)
            state.isBusy = false
            switch result {
            case .success:
                actionsSubject.send(.done)
            case .failure:
                state.bindings.errorMessage = WatchStrings.sendLocationFailed
            }
        }
    }

    private func shareLive(_ duration: LiveShareDuration) {
        guard state.canShareLive else { return }
        if case .sharing(let otherRoomID, _, _) = liveLocationService.state, otherRoomID != roomID {
            state.otherShareRoomName = roomName(otherRoomID) ?? WatchStrings.anotherChat
            pendingReplace = duration
            state.bindings.confirmReplace = duration
        } else {
            startLiveShare(duration)
        }
    }

    private func startLiveShare(_ duration: LiveShareDuration) {
        state.isBusy = true
        Task {
            let result = await liveLocationService.start(roomID: roomID, duration: duration.duration)
            state.isBusy = false
            switch result {
            case .success:
                actionsSubject.send(.done)
            case .failure(let error):
                MXLog.error("Couldn't start live location: \(error)")
                // Any earlier share has already been stopped by now, so the message mustn't suggest it continues.
                state.bindings.errorMessage = WatchStrings.startLiveFailed
            }
        }
    }
}
