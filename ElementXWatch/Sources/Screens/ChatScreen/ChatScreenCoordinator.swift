//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct ChatScreenCoordinatorParameters {
    let roomID: String
    let roomName: String
    let isDirect: Bool
    let timelineProxy: TimelineProxyProtocol
    /// Held for the chat's lifetime: releasing it stops the room's live location updates.
    let roomLocationProxy: RoomLocationProxyProtocol?
    let locationServices: LocationServices
    let mapSnapshotLoader: MapSnapshotLoaderProtocol
    /// Names another room, e.g. the one a live share runs in; `nil` if unknown.
    let roomNameForID: (String) -> String?
}

final class ChatScreenCoordinator: CoordinatorProtocol {
    private let parameters: ChatScreenCoordinatorParameters
    private let viewModel: ChatScreenViewModel
    /// Kept while its presentation is up: the chat re-renders on every timeline or live location update.
    private var locationMap: (id: UUID, coordinator: LocationMapScreenCoordinator)?
    private var attachments: (id: UUID, coordinator: AttachmentsScreenCoordinator)?
    private var attachmentsCancellable: AnyCancellable?

    init(parameters: ChatScreenCoordinatorParameters) {
        self.parameters = parameters
        viewModel = ChatScreenViewModel(roomName: parameters.roomName, isDirect: parameters.isDirect,
                                        timelineProxy: parameters.timelineProxy, roomLocationProxy: parameters.roomLocationProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(ChatScreen(context: viewModel.context,
                           locationMap: { [weak self] in self?.locationMapScreen(for: $0) ?? AnyView(EmptyView()) },
                           attachments: { [weak self] in self?.attachmentsScreen(for: $0) ?? AnyView(EmptyView()) }))
    }

    private func locationMapScreen(for presentation: LocationMapPresentation) -> AnyView {
        if let locationMap, locationMap.id == presentation.id {
            return locationMap.coordinator.toPresentable()
        }

        let coordinator = LocationMapScreenCoordinator(mode: presentation.mode, liveLocationsPublisher: parameters.roomLocationProxy?.liveLocationsPublisher)
        locationMap = (presentation.id, coordinator)
        return coordinator.toPresentable()
    }

    private func attachmentsScreen(for presentation: AttachmentsPresentation) -> AnyView {
        if let attachments, attachments.id == presentation.id {
            return attachments.coordinator.toPresentable()
        }

        let parameters = parameters
        let coordinator = AttachmentsScreenCoordinator {
            LocationSharingScreenCoordinator(parameters: .init(roomID: parameters.roomID,
                                                               roomName: parameters.roomNameForID,
                                                               locationServices: parameters.locationServices,
                                                               timelineProxy: parameters.timelineProxy,
                                                               mapSnapshotLoader: parameters.mapSnapshotLoader))
        }
        attachmentsCancellable = coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .dismiss: self?.viewModel.dismissAttachments()
                }
            }
        coordinator.start()
        attachments = (presentation.id, coordinator)
        return coordinator.toPresentable()
    }
}
