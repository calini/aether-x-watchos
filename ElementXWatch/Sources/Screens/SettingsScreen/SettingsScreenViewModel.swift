//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

typealias SettingsScreenViewModelType = StateStoreViewModelV2<SettingsScreenViewState, SettingsScreenViewAction>

final class SettingsScreenViewModel: SettingsScreenViewModelType, SettingsScreenViewModelProtocol {
    private let audioSelfTest: @Sendable () async -> Bool
    private let actionsSubject = PassthroughSubject<SettingsScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<SettingsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol,
         audioSelfTest: @escaping @Sendable () async -> Bool = { await Task.detached { OpusCodec.selfTest() }.value }) {
        self.audioSelfTest = audioSelfTest
        super.init(initialViewState: SettingsScreenViewState(userID: clientProxy.userID))

        clientProxy.verificationStatePublisher
            .sink { [weak self] verification in self?.state.verification = verification }
            .store(in: &cancellables)

        Task { [weak self] in
            let displayName = await clientProxy.loadDisplayName()
            self?.state.displayName = displayName
        }
    }

    override func process(viewAction: SettingsScreenViewAction) {
        switch viewAction {
        case .verifySession:
            actionsSubject.send(.verifySession)
        case .signOut:
            state.bindings.isConfirmingSignOut = true
        case .confirmSignOut:
            state.bindings.isConfirmingSignOut = false
            actionsSubject.send(.signOut)
        case .checkAudioSupport:
            checkAudioSupport()
        }
    }

    private func checkAudioSupport() {
        guard state.audioSupport != .checking else { return }
        state.audioSupport = .checking
        Task { [weak self, audioSelfTest] in
            let isSupported = await audioSelfTest()
            self?.state.audioSupport = isSupported ? .supported : .unsupported
        }
    }
}
