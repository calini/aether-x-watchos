//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine

typealias AttachmentsScreenViewModelType = StateStoreViewModelV2<AttachmentsScreenViewState, AttachmentsScreenViewAction>

final class AttachmentsScreenViewModel: AttachmentsScreenViewModelType, AttachmentsScreenViewModelProtocol {
    private let actionsSubject = PassthroughSubject<AttachmentsScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<AttachmentsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init() {
        super.init(initialViewState: AttachmentsScreenViewState())
    }

    override func process(viewAction: AttachmentsScreenViewAction) {
        switch viewAction {
        case .location:
            actionsSubject.send(.location)
        case .voiceMessage:
            actionsSubject.send(.voiceMessage)
        }
    }
}
