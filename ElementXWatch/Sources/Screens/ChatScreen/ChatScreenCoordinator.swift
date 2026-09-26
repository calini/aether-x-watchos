//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

final class ChatScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ChatScreenViewModel
    /// Held for the chat's lifetime: releasing it stops the room's live location updates.
    private let roomLocationProxy: RoomLocationProxyProtocol?
    /// Kept while its presentation is up: the chat re-renders on every timeline or live location update.
    private var locationMap: (id: UUID, coordinator: LocationMapScreenCoordinator)?

    init(roomName: String, isDirect: Bool, timelineProxy: TimelineProxyProtocol, roomLocationProxy: RoomLocationProxyProtocol?) {
        self.roomLocationProxy = roomLocationProxy
        viewModel = ChatScreenViewModel(roomName: roomName, isDirect: isDirect, timelineProxy: timelineProxy, roomLocationProxy: roomLocationProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(ChatScreen(context: viewModel.context) { [weak self] presentation in
            self?.locationMapScreen(for: presentation) ?? AnyView(EmptyView())
        })
    }

    private func locationMapScreen(for presentation: LocationMapPresentation) -> AnyView {
        if let locationMap, locationMap.id == presentation.id {
            return locationMap.coordinator.toPresentable()
        }

        let coordinator = LocationMapScreenCoordinator(mode: presentation.mode, liveLocationsPublisher: roomLocationProxy?.liveLocationsPublisher)
        locationMap = (presentation.id, coordinator)
        return coordinator.toPresentable()
    }
}
