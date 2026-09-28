//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct LocationSharingScreenCoordinatorParameters {
    let roomID: String
    let roomName: (String) -> String?
    let locationServices: LocationServices
    let timelineProxy: TimelineProxyProtocol
    let mapSnapshotLoader: MapSnapshotLoaderProtocol?
}

enum LocationSharingScreenCoordinatorAction {
    case done
}

final class LocationSharingScreenCoordinator: CoordinatorProtocol {
    private let viewModel: LocationSharingScreenViewModel
    private let actionsSubject = PassthroughSubject<LocationSharingScreenCoordinatorAction, Never>()
    private var cancellables = Set<AnyCancellable>()

    var actionsPublisher: AnyPublisher<LocationSharingScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(parameters: LocationSharingScreenCoordinatorParameters) {
        let timelineProxy = parameters.timelineProxy
        viewModel = LocationSharingScreenViewModel(roomID: parameters.roomID,
                                                   roomName: parameters.roomName,
                                                   locationProvider: parameters.locationServices.locationProvider,
                                                   liveLocationService: parameters.locationServices.liveLocationService,
                                                   sendLocation: { await timelineProxy.sendLocation($0, description: nil) },
                                                   snapshotLoader: parameters.mapSnapshotLoader)
    }

    func start() {
        viewModel.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .done: self?.actionsSubject.send(.done)
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        AnyView(LocationSharingScreen(context: viewModel.context))
    }
}
