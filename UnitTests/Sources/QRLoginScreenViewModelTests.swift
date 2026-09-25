//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Foundation
import Testing

@Suite
struct QRLoginScreenViewModelTests {
    @Test
    func progressDrivesTheSteps() async throws {
        let service = QRLoginServiceMock()
        let gate = AsyncGate()
        service.loginWithGeneratedQRCodeOnProgressClosure = { onProgress in
            onProgress(.showingQRCode(Data([1, 2])))
            onProgress(.waitingForApproval(userCode: "XY12"))
            await gate.wait()
            return .failure(.declined)
        }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)

        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .waitingForApproval(userCode: "XY12") }
        await gate.open()

        try await waitUntil { viewModel.context.viewState.step == .failed(.declined) }
    }

    @Test
    func successEmitsSignedIn() async throws {
        let service = QRLoginServiceMock()
        let clientProxy = ClientProxyMock()
        service.loginWithGeneratedQRCodeOnProgressClosure = { _ in .success(clientProxy) }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)
        var signedIn: ClientProxyProtocol?
        let cancellable = viewModel.actionsPublisher.sink { action in
            if case .signedIn(let proxy) = action { signedIn = proxy }
        }

        viewModel.context.send(viewAction: .start)

        try await waitUntil { signedIn != nil }
        #expect(signedIn === clientProxy)
        cancellable.cancel()
    }

    @Test
    func retryStartsAFreshFlow() async throws {
        let service = QRLoginServiceMock()
        service.loginWithGeneratedQRCodeOnProgressClosure = { _ in .failure(.expired) }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .failed(.expired) }

        let stillShowingCode = AsyncGate() // Never opened: stays on the QR code for the rest of the test.
        service.loginWithGeneratedQRCodeOnProgressClosure = { onProgress in
            onProgress(.showingQRCode(Data([9])))
            await stillShowingCode.wait()
            return .failure(.unknown)
        }
        viewModel.context.send(viewAction: .retry)

        try await waitUntil { viewModel.context.viewState.step == .showingQRCode(Data([9])) }
        #expect(service.loginWithGeneratedQRCodeOnProgressCallsCount == 2)
    }

    @Test
    func cancelReturnsToIntroAndIgnoresLateUpdates() async throws {
        let service = QRLoginServiceMock()
        let gate = AsyncGate()
        service.loginWithGeneratedQRCodeOnProgressClosure = { onProgress in
            onProgress(.showingQRCode(Data([1])))
            await gate.wait()
            onProgress(.syncingSecrets)
            return .failure(.unknown)
        }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .showingQRCode(Data([1])) }

        viewModel.context.send(viewAction: .cancel)
        await gate.open()
        for _ in 0..<20 { await Task.yield() }

        #expect(viewModel.context.viewState.step == .intro)
    }

    @Test
    func checkCodeIsSentAndFailureIsShown() async throws {
        let sender = FakeCheckCodeSender(shouldFail: true)
        let service = QRLoginServiceMock()
        let stillEnteringCode = AsyncGate() // Never opened: the outer login task stays pending.
        service.loginWithGeneratedQRCodeOnProgressClosure = { onProgress in
            onProgress(.enteringCheckCode(sender))
            await stillEnteringCode.wait()
            return .failure(.unknown)
        }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .enteringCheckCode }

        viewModel.context.checkCode = 42
        viewModel.context.send(viewAction: .submitCheckCode)

        try await waitUntil { viewModel.context.viewState.step == .failed(.insecureConnection) }
        #expect(sender.sentCodes == [42])
    }
}

// MARK: - Helpers

final class FakeCheckCodeSender: CheckCodeSending {
    private let shouldFail: Bool
    private(set) var sentCodes: [UInt8] = []

    init(shouldFail: Bool) {
        self.shouldFail = shouldFail
    }

    func send(code: UInt8) async throws {
        sentCodes.append(code)
        if shouldFail { throw CancellationError() }
    }
}
