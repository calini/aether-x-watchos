//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Testing

@Suite
struct SessionVerificationScreenViewModelTests {
    @Test
    func fullHappyPath() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        let emojis = [VerificationEmoji(symbol: "🐶", description: "Dog")]

        viewModel.context.send(viewAction: .start)
        #expect(viewModel.context.viewState.step == .waitingForAcceptance)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }

        actions.send(.acceptedVerificationRequest)
        try await waitUntil { proxy.startSasVerificationCallsCount == 1 }

        actions.send(.receivedVerificationData(.emojis(emojis)))
        #expect(viewModel.context.viewState.step == .comparing(.emojis(emojis)))

        viewModel.context.send(viewAction: .match)
        #expect(viewModel.context.viewState.step == .confirming)
        try await waitUntil { proxy.approveVerificationCallsCount == 1 }

        actions.send(.finished)
        #expect(viewModel.context.viewState.step == .verified)
    }

    @Test
    func noMatchDeclines() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }
        actions.send(.acceptedVerificationRequest)
        try await waitUntil { proxy.startSasVerificationCallsCount == 1 }
        actions.send(.receivedVerificationData(.decimals([1, 2, 3])))
        #expect(viewModel.context.viewState.step == .comparing(.decimals([1, 2, 3])))

        viewModel.context.send(viewAction: .noMatch)
        #expect(viewModel.context.viewState.step == .declined)

        try await waitUntil { proxy.declineVerificationCallsCount == 1 }
    }

    /// Regression test: `SDKListener.onMainActor` can deliver several buffered proxy actions back-to-back
    /// on one main-actor turn, before the `startSasVerification` call started by the first of them has
    /// even returned. The screen must still land on `.comparing`, not have that call's completion (or
    /// failure) clobber a step it no longer set.
    @Test
    func backToBackAcceptedAndDataDoesNotLoseComparingStep() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        let emojis = [VerificationEmoji(symbol: "🐶", description: "Dog")]

        viewModel.context.send(viewAction: .start)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }
        actions.send(.acceptedVerificationRequest)
        actions.send(.receivedVerificationData(.emojis(emojis)))
        await Task.yield()

        #expect(viewModel.context.viewState.step == .comparing(.emojis(emojis)))
    }

    @Test
    func cancelledOrFailedOffersTryAgain() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }

        actions.send(.cancelled)
        try await waitUntil { viewModel.context.viewState.step == .cancelled }

        viewModel.context.send(viewAction: .tryAgain)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 2 }

        actions.send(.failed)
        try await waitUntil { viewModel.context.viewState.step == .failed }
    }

    @Test
    func requestFailureShowsFailed() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.requestDeviceVerificationReturnValue = .failure(.failedRequestingVerification)

        viewModel.context.send(viewAction: .start)

        try await waitUntil { viewModel.context.viewState.step == .failed }
    }

    /// Right after a password sign-in the own identity isn't downloaded yet, so the controller only
    /// becomes available a little later: the screen must keep waiting rather than fail.
    @Test
    func startWaitsForTheControllerToBecomeAvailable() async throws {
        let proxy = SessionVerificationControllerProxyMock.idle
        let loader = ControllerLoader(results: [nil, nil, proxy])
        let viewModel = makeViewModel(loader: loader)

        viewModel.context.send(viewAction: .start)
        #expect(viewModel.context.viewState.step == .waitingForAcceptance)

        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }
        #expect(loader.callsCount == 3)
        #expect(viewModel.context.viewState.step == .waitingForAcceptance)
        try await Task.sleep(for: .milliseconds(50))
        #expect(proxy.requestDeviceVerificationCallsCount == 1)
    }

    @Test
    func unavailableControllerFailsAfterTheTimeoutAndTryAgainReloads() async throws {
        let loader = ControllerLoader(results: [nil])
        let viewModel = makeViewModel(loader: loader, timeout: .milliseconds(100))

        viewModel.context.send(viewAction: .start)
        #expect(viewModel.context.viewState.step == .waitingForAcceptance)
        try await waitUntil { loader.callsCount > 1 }
        #expect(viewModel.context.viewState.step == .waitingForAcceptance)

        try await waitUntil { viewModel.context.viewState.step == .failed }
        let callsCount = loader.callsCount
        viewModel.context.send(viewAction: .tryAgain)

        #expect(viewModel.context.viewState.step == .waitingForAcceptance)
        try await waitUntil { loader.callsCount > callsCount }
        try await waitUntil { viewModel.context.viewState.step == .failed }
    }

    @Test
    func cancelWhileWaitingForTheControllerStopsRetrying() async throws {
        let proxy = SessionVerificationControllerProxyMock.idle
        let loader = ControllerLoader(results: [nil, proxy])
        let viewModel = makeViewModel(loader: loader, retryInterval: .milliseconds(50))

        viewModel.context.send(viewAction: .start)
        try await waitUntil { loader.callsCount == 1 }
        viewModel.context.send(viewAction: .cancel)
        #expect(viewModel.context.viewState.step == .cancelled)

        try await Task.sleep(for: .milliseconds(200))
        #expect(loader.callsCount == 1)
        #expect(proxy.requestDeviceVerificationCallsCount == 0)
        #expect(viewModel.context.viewState.step == .cancelled)
    }

    /// The controller is cached per client, so a reload returns the same proxy: its actions must still
    /// be handled once, not once per attempt.
    @Test
    func tryAgainDoesNotSubscribeTwice() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }
        actions.send(.cancelled)
        viewModel.context.send(viewAction: .tryAgain)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 2 }

        actions.send(.acceptedVerificationRequest)

        try await waitUntil { proxy.startSasVerificationCallsCount == 1 }
        try await Task.sleep(for: .milliseconds(50))
        #expect(proxy.startSasVerificationCallsCount == 1)
    }

    @Test
    func cancelWhileWaitingCancelsAndDismissIsForwarded() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        var dismissed = false
        let cancellable = viewModel.actionsPublisher.sink { if case .dismiss = $0 { dismissed = true } }
        viewModel.context.send(viewAction: .start)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }

        viewModel.context.send(viewAction: .cancel)
        #expect(viewModel.context.viewState.step == .cancelled)
        try await waitUntil { proxy.cancelVerificationCallsCount == 1 }
        viewModel.context.send(viewAction: .dismiss)

        #expect(dismissed)
        cancellable.cancel()
    }

    @Test
    func cancelDuringConfirmingCallsCancelVerification() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }
        actions.send(.acceptedVerificationRequest)
        actions.send(.receivedVerificationData(.decimals([1, 2, 3])))
        viewModel.context.send(viewAction: .match)
        #expect(viewModel.context.viewState.step == .confirming)

        viewModel.context.send(viewAction: .cancel)

        #expect(viewModel.context.viewState.step == .cancelled)
        try await waitUntil { proxy.cancelVerificationCallsCount == 1 }
    }

    /// Buffered/shared-proxy actions must be gated on the current step: a stray `.cancelled` for a
    /// finished flow (e.g. a delayed echo) must not undo `.verified`.
    @Test
    func strayCancelledAfterVerifiedIsIgnored() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }
        actions.send(.acceptedVerificationRequest)
        actions.send(.receivedVerificationData(.decimals([1, 2, 3])))
        viewModel.context.send(viewAction: .match)
        actions.send(.finished)
        #expect(viewModel.context.viewState.step == .verified)

        actions.send(.cancelled)

        #expect(viewModel.context.viewState.step == .verified)
    }

    /// A previous attempt's `.acceptedVerificationRequest` arriving after the user cancelled it must not
    /// start a new SAS verification.
    @Test
    func acceptedRequestWhileCancelledDoesNotStartSas() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 1 }
        viewModel.context.send(viewAction: .cancel)
        #expect(viewModel.context.viewState.step == .cancelled)

        actions.send(.acceptedVerificationRequest)

        #expect(viewModel.context.viewState.step == .cancelled)
        #expect(proxy.startSasVerificationCallsCount == 0)
    }

    // MARK: - Helpers

    private func makeViewModel() -> (SessionVerificationScreenViewModel, SessionVerificationControllerProxyMock, PassthroughSubject<SessionVerificationControllerProxyAction, Never>) {
        let actions = PassthroughSubject<SessionVerificationControllerProxyAction, Never>()
        let proxy = SessionVerificationControllerProxyMock()
        proxy.actionsPublisher = actions.eraseToAnyPublisher()
        proxy.requestDeviceVerificationReturnValue = .success(())
        proxy.startSasVerificationReturnValue = .success(())
        proxy.approveVerificationReturnValue = .success(())
        proxy.declineVerificationReturnValue = .success(())
        proxy.cancelVerificationReturnValue = .success(())
        return (makeViewModel(loader: ControllerLoader(results: [proxy])), proxy, actions)
    }

    private func makeViewModel(loader: ControllerLoader,
                               retryInterval: Duration = .milliseconds(10),
                               timeout: Duration = .seconds(30)) -> SessionVerificationScreenViewModel {
        SessionVerificationScreenViewModel(controllerLoader: { await loader.load() }, retryInterval: retryInterval, timeout: timeout)
    }
}

/// Returns `results` in order, repeating the last one once they run out.
private final class ControllerLoader {
    private let results: [SessionVerificationControllerProxyProtocol?]
    private(set) var callsCount = 0

    init(results: [SessionVerificationControllerProxyProtocol?]) {
        self.results = results
    }

    func load() async -> SessionVerificationControllerProxyProtocol? {
        callsCount += 1
        return results[min(callsCount, results.count) - 1]
    }
}
