//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine

typealias SessionVerificationScreenViewModelType = StateStoreViewModelV2<SessionVerificationScreenViewState, SessionVerificationScreenViewAction>

final class SessionVerificationScreenViewModel: SessionVerificationScreenViewModelType, SessionVerificationScreenViewModelProtocol {
    private let controllerLoader: () async -> SessionVerificationControllerProxyProtocol?
    private let retryInterval: Duration
    private let timeout: Duration
    private let actionsSubject = PassthroughSubject<SessionVerificationScreenViewModelAction, Never>()
    /// Set once loaded; the SDK controller is cached per client, so it never changes afterwards.
    private var controllerProxy: SessionVerificationControllerProxyProtocol?
    private var loadingTask: Task<Void, Never>?
    private var loadingTimeoutTask: Task<Void, Never>?

    var actionsPublisher: AnyPublisher<SessionVerificationScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    /// - Parameters:
    ///   - controllerLoader: Returns `nil` while the controller is unavailable, e.g. before the own
    ///     identity has been downloaded right after sign-in. Retried every `retryInterval`, up to `timeout`.
    init(controllerLoader: @escaping () async -> SessionVerificationControllerProxyProtocol?,
         retryInterval: Duration = .seconds(3),
         timeout: Duration = .seconds(30)) {
        self.controllerLoader = controllerLoader
        self.retryInterval = retryInterval
        self.timeout = timeout
        super.init(initialViewState: SessionVerificationScreenViewState())
    }

    override func process(viewAction: SessionVerificationScreenViewAction) {
        switch viewAction {
        case .start, .tryAgain:
            if let controllerProxy {
                perform(setting: .waitingForAcceptance) { await controllerProxy.requestDeviceVerification() }
            } else {
                loadControllerThenRequestVerification()
            }
        case .match:
            guard let controllerProxy else { return }
            perform(setting: .confirming) { await controllerProxy.approveVerification() }
        case .noMatch:
            guard let controllerProxy else { return }
            perform(setting: .declined) { await controllerProxy.declineVerification() }
        case .cancel:
            if loadingTask != nil {
                stopLoadingController()
                state.step = .cancelled
                return
            }
            guard let controllerProxy else { return }
            perform(setting: .cancelled) { await controllerProxy.cancelVerification() }
        case .dismiss:
            stopLoadingController()
            actionsSubject.send(.dismiss)
        }
    }

    /// Shows the waiting step while retrying, so a controller that turns up within `timeout` is used
    /// straight away. Only the first miss is logged, the client proxy logs the underlying error.
    private func loadControllerThenRequestVerification() {
        stopLoadingController()
        state.step = .waitingForAcceptance

        loadingTask = Task { [weak self, controllerLoader, retryInterval] in
            var hasMissed = false
            while !Task.isCancelled {
                if let controllerProxy = await controllerLoader() {
                    guard !Task.isCancelled else { return }
                    self?.didLoadController(controllerProxy, afterRetrying: hasMissed)
                    return
                }
                if !hasMissed {
                    MXLog.info("Session verification controller unavailable, retrying")
                    hasMissed = true
                }
                guard (try? await Task.sleep(for: retryInterval)) != nil, self != nil else { return }
            }
        }
        loadingTimeoutTask = Task { [weak self, timeout] in
            guard (try? await Task.sleep(for: timeout)) != nil, let self else { return }
            MXLog.error("Session verification controller still unavailable after \(timeout)")
            stopLoadingController()
            state.step = .failed
        }
    }

    private func didLoadController(_ controllerProxy: SessionVerificationControllerProxyProtocol, afterRetrying: Bool) {
        stopLoadingController()
        if afterRetrying {
            MXLog.info("Session verification controller became available")
        }
        self.controllerProxy = controllerProxy
        controllerProxy.actionsPublisher
            .sink { [weak self] action in self?.handle(action) }
            .store(in: &cancellables)
        perform(setting: .waitingForAcceptance) { await controllerProxy.requestDeviceVerification() }
    }

    private func stopLoadingController() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = nil
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
            guard state.isFlowActive else { return }
            state.step = .cancelled
        case .failed:
            guard state.isFlowActive else { return }
            state.step = .failed
        }
    }

    /// Sets `step` synchronously, then issues the call, so a step this call didn't set can never be
    /// clobbered by its (possibly late) result.
    private func perform(setting step: SessionVerificationStep, _ call: @escaping () async -> Result<Void, SessionVerificationControllerProxyError>) {
        state.step = step
        Task { [weak self] in
            // Call before checking `self`: a cancel sent as the screen is dismissed must still reach the SDK.
            guard case .failure = await call(), let self else { return }
            // Only fail if nothing else has moved the step on since, and never override a final user choice.
            guard state.step == step, step != .declined, step != .cancelled else { return }
            state.step = .failed
        }
    }
}
