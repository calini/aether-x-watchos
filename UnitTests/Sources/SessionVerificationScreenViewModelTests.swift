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
        try await waitUntil { viewModel.context.viewState.step == .waitingForAcceptance }
        #expect(proxy.requestDeviceVerificationCallsCount == 1)

        actions.send(.acceptedVerificationRequest)
        try await waitUntil { proxy.startSasVerificationCallsCount == 1 }

        actions.send(.receivedVerificationData(.emojis(emojis)))
        try await waitUntil { viewModel.context.viewState.step == .comparing(.emojis(emojis)) }

        viewModel.context.send(viewAction: .match)
        try await waitUntil { proxy.approveVerificationCallsCount == 1 }
        #expect(viewModel.context.viewState.step == .confirming)

        actions.send(.finished)
        try await waitUntil { viewModel.context.viewState.step == .verified }
    }

    @Test
    func noMatchDeclines() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        actions.send(.acceptedVerificationRequest)
        actions.send(.receivedVerificationData(.decimals([1, 2, 3])))
        try await waitUntil { viewModel.context.viewState.step == .comparing(.decimals([1, 2, 3])) }

        viewModel.context.send(viewAction: .noMatch)

        try await waitUntil { viewModel.context.viewState.step == .declined }
        #expect(proxy.declineVerificationCallsCount == 1)
    }

    @Test
    func cancelledOrFailedOffersTryAgain() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .waitingForAcceptance }

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

    @Test
    func missingControllerShowsFailed() async throws {
        let viewModel = SessionVerificationScreenViewModel(controllerProxy: nil)
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .failed }
    }

    @Test
    func cancelWhileWaitingCancelsAndDismissIsForwarded() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        var dismissed = false
        let cancellable = viewModel.actionsPublisher.sink { if case .dismiss = $0 { dismissed = true } }
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .waitingForAcceptance }

        viewModel.context.send(viewAction: .cancel)
        try await waitUntil { proxy.cancelVerificationCallsCount == 1 }
        viewModel.context.send(viewAction: .dismiss)

        #expect(dismissed)
        cancellable.cancel()
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
        return (SessionVerificationScreenViewModel(controllerProxy: proxy), proxy, actions)
    }
}
