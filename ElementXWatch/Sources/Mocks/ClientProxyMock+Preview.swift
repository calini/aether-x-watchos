//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

extension ClientProxyMock {
    @MainActor static var preview: ClientProxyMock {
        let mock = ClientProxyMock()
        let provider = RoomSummaryProviderMock()
        provider.roomsPublisher = Just([]).eraseToAnyPublisher()
        mock.roomSummaryProvider = provider
        mock.syncStatePublisher = Just(.running).eraseToAnyPublisher()
        mock.verificationStatePublisher = Just(.verified).eraseToAnyPublisher()
        mock.actionsPublisher = Empty().eraseToAnyPublisher()
        mock.userID = "@alice:matrix.org"
        mock.loadDisplayNameReturnValue = "Alice"
        mock.timelineProxyForReturnValue = nil
        return mock
    }
}
