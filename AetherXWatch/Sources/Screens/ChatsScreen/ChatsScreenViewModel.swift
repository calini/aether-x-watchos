//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias ChatsScreenViewModelType = StateStoreViewModelV2<ChatsScreenViewState, ChatsScreenViewAction>

final class ChatsScreenViewModel: ChatsScreenViewModelType, ChatsScreenViewModelProtocol {
    private let actionsSubject = PassthroughSubject<ChatsScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<ChatsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol) {
        super.init(initialViewState: ChatsScreenViewState())

        clientProxy.roomSummaryProvider.roomsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rooms in
                self?.state.rooms = rooms
                self?.state.isLoading = false
            }
            .store(in: &cancellables)

        clientProxy.syncStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncState in self?.state.syncState = syncState }
            .store(in: &cancellables)
    }

    override func process(viewAction: ChatsScreenViewAction) {
        switch viewAction {
        case .selectRoom(let roomID):
            guard let room = state.rooms.first(where: { $0.id == roomID }) else { return }
            actionsSubject.send(.openRoom(room))
        case .openSettings:
            actionsSubject.send(.openSettings)
        }
    }
}
