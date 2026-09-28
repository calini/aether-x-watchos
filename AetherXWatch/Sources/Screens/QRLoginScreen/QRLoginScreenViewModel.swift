//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias QRLoginScreenViewModelType = StateStoreViewModelV2<QRLoginScreenViewState, QRLoginScreenViewAction>

final class QRLoginScreenViewModel: QRLoginScreenViewModelType, QRLoginScreenViewModelProtocol {
    private let qrLoginService: QRLoginServiceProtocol
    private let actionsSubject = PassthroughSubject<QRLoginScreenViewModelAction, Never>()

    private var loginTask: Task<Void, Never>?
    private var checkCodeSender: CheckCodeSending?
    /// Identifies the current attempt so updates from a cancelled one are ignored.
    private var attempt = 0

    var actionsPublisher: AnyPublisher<QRLoginScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(qrLoginService: QRLoginServiceProtocol) {
        self.qrLoginService = qrLoginService
        super.init(initialViewState: QRLoginScreenViewState())
    }

    override func process(viewAction: QRLoginScreenViewAction) {
        switch viewAction {
        case .start, .retry:
            startLogin()
        case .submitCheckCode:
            submitCheckCode()
        case .cancel:
            stopLogin()
            state.step = .intro
        }
    }

    private func startLogin() {
        stopLogin()
        state.bindings.checkCode = 0
        state.step = .preparing

        let currentAttempt = attempt
        loginTask = Task { [weak self, qrLoginService] in
            let result = await qrLoginService.loginWithGeneratedQRCode { [weak self] progress in
                guard let self, attempt == currentAttempt else { return }
                handle(progress)
            }
            guard let self, attempt == currentAttempt else { return }

            switch result {
            case .success(let clientProxy):
                actionsSubject.send(.signedIn(clientProxy))
            case .failure(let error):
                state.step = .failed(error)
            }
        }
    }

    private func stopLogin() {
        attempt += 1
        loginTask?.cancel()
        loginTask = nil
        checkCodeSender = nil
    }

    private func handle(_ progress: QRLoginProgress) {
        MXLog.info("QR login progress: \(progress)")
        switch progress {
        case .starting:
            state.step = .preparing
        case .showingQRCode(let data):
            state.step = .showingQRCode(data)
        case .enteringCheckCode(let sender):
            checkCodeSender = sender
            state.step = .enteringCheckCode
        case .waitingForApproval(let userCode):
            state.step = .waitingForApproval(userCode: userCode)
        case .syncingSecrets:
            state.step = .syncingSecrets
        }
    }

    private func submitCheckCode() {
        guard let checkCodeSender else { return }
        let code = UInt8(clamping: state.bindings.checkCode)
        let currentAttempt = attempt
        state.step = .sendingCheckCode

        Task { [weak self] in
            do {
                try await checkCodeSender.send(code: code)
            } catch {
                MXLog.error("Failed sending the check code: \(error)")
                guard let self, attempt == currentAttempt else { return }
                stopLogin()
                state.step = .failed(.insecureConnection)
            }
        }
    }
}
