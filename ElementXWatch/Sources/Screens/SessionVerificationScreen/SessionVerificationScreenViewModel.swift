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

    /// Gated on the expected step: the controller proxy is cached per client and shared across attempts
    /// (no flow ID), so a stray or buffered action from an earlier attempt must not be misapplied to
    /// whatever the screen shows now.
    ///
    /// Known limitation: without a flow ID, a stray `.cancelled`/`.failed` echo from a just-cancelled
    /// attempt can still be misread as belonging to a fresh "Try again" if it arrives while that new
    /// attempt is also in an active step.
    private func handle(_ action: SessionVerificationControllerProxyAction) {
        switch action {
        case .acceptedVerificationRequest:
            guard let controllerProxy, state.step == .waitingForAcceptance else { return }
            perform(setting: .startingSas) { await controllerProxy.startSasVerification() }
        case .startedSasVerification:
            break
        case .receivedVerificationData(let data):
            switch state.step {
            case .waitingForAcceptance, .startingSas:
                state.step = .comparing(data)
            default:
                break
            }
        case .finished:
            switch state.step {
            case .comparing, .confirming:
                state.step = .verified
            default:
                break
            }
        case .cancelled:
            guard isFlowActive else { return }
            state.step = .cancelled
        case .failed:
            guard isFlowActive else { return }
            state.step = .failed
        }
    }

    /// Whether the flow is still running, i.e. not idle and not already at a terminal step.
    private var isFlowActive: Bool {
        switch state.step {
        case .intro, .verified, .declined, .cancelled, .failed:
            false
        case .waitingForAcceptance, .startingSas, .comparing, .confirming:
            true
        }
    }

    /// Sets `step` synchronously, then issues the call, so a step this call didn't set can never be
    /// clobbered by its (possibly late) result.
    private func perform(setting step: SessionVerificationStep, _ call: @escaping () async -> Result<Void, SessionVerificationControllerProxyError>) {
        state.step = step
        Task { [weak self] in
            guard let self, case .failure = await call() else { return }
            // Only fail if nothing else has moved the step on since, and never override a final user choice.
            guard state.step == step, step != .declined, step != .cancelled else { return }
            state.step = .failed
        }
    }
}
