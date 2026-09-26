//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

typealias SessionVerificationScreenViewModelType = StateStoreViewModelV2<SessionVerificationScreenViewState, SessionVerificationScreenViewAction>

final class SessionVerificationScreenViewModel: SessionVerificationScreenViewModelType, SessionVerificationScreenViewModelProtocol {
    private let controllerProxy: SessionVerificationControllerProxyProtocol?
    private let actionsSubject = PassthroughSubject<SessionVerificationScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<SessionVerificationScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(controllerProxy: SessionVerificationControllerProxyProtocol?) {
        self.controllerProxy = controllerProxy
        super.init(initialViewState: SessionVerificationScreenViewState())

        controllerProxy?.actionsPublisher
            .sink { [weak self] action in self?.handle(action) }
            .store(in: &cancellables)
    }

    override func process(viewAction: SessionVerificationScreenViewAction) {
        switch viewAction {
        case .start, .tryAgain:
            guard let controllerProxy else {
                state.step = .failed
                return
            }
            perform(setting: .waitingForAcceptance) { await controllerProxy.requestDeviceVerification() }
        case .match:
            guard let controllerProxy else { return }
            perform(setting: .confirming) { await controllerProxy.approveVerification() }
        case .noMatch:
            guard let controllerProxy else { return }
            perform(setting: .declined) { await controllerProxy.declineVerification() }
        case .cancel:
            guard let controllerProxy else { return }
            perform(setting: .cancelled) { await controllerProxy.cancelVerification() }
        case .dismiss:
            actionsSubject.send(.dismiss)
        }
    }

    /// The SDK finishes/cancels the flow itself after a decline; that would otherwise clobber the declined message.
    private func handle(_ action: SessionVerificationControllerProxyAction) {
        switch action {
        case .acceptedVerificationRequest:
            guard let controllerProxy else { return }
            perform(setting: .startingSas) { await controllerProxy.startSasVerification() }
        case .startedSasVerification:
            break
        case .receivedVerificationData(let data):
            state.step = .comparing(data)
        case .finished:
            if state.step != .declined { state.step = .verified }
        case .cancelled:
            if state.step != .declined { state.step = .cancelled }
        case .failed:
            state.step = .failed
        }
    }

    /// Sets `step` and issues the call together, so the visible step always matches a call already in flight.
    private func perform(setting step: SessionVerificationStep, _ call: @escaping () async -> Result<Void, SessionVerificationControllerProxyError>) {
        Task { [weak self] in
            guard let self else { return }
            state.step = step
            // A failure after the user already declined or cancelled shouldn't override that outcome.
            if case .failure = await call(), state.step != .declined, state.step != .cancelled {
                state.step = .failed
            }
        }
    }
}
