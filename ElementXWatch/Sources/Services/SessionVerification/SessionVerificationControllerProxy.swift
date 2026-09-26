//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MatrixRustSDK

final class SessionVerificationControllerProxy: SessionVerificationControllerProxyProtocol {
    private let controller: SessionVerificationController
    private let actionsSubject = PassthroughSubject<SessionVerificationControllerProxyAction, Never>()

    var actionsPublisher: AnyPublisher<SessionVerificationControllerProxyAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(controller: SessionVerificationController) {
        self.controller = controller
        controller.setDelegate(delegate: SessionVerificationDelegateForwarder { [weak self] action in
            MXLog.info("Session verification: \(action)")
            self?.actionsSubject.send(action)
        })
    }

    deinit {
        controller.setDelegate(delegate: nil)
    }

    func requestDeviceVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedRequestingVerification) { try await self.controller.requestDeviceVerification() }
    }

    func startSasVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedStartingSasVerification) { try await self.controller.startSasVerification() }
    }

    func approveVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedApprovingVerification) { try await self.controller.approveVerification() }
    }

    func declineVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedDecliningVerification) { try await self.controller.declineVerification() }
    }

    func cancelVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedCancellingVerification) { try await self.controller.cancelVerification() }
    }

    private func run(_ failure: SessionVerificationControllerProxyError, _ operation: () async throws -> Void) async -> Result<Void, SessionVerificationControllerProxyError> {
        do {
            try await operation()
            return .success(())
        } catch {
            MXLog.error("Session verification step failed (\(failure)): \(error)")
            return .failure(failure)
        }
    }
}

/// Forwards the SDK's delegate callbacks (background threads) onto the main actor.
private nonisolated final class SessionVerificationDelegateForwarder: SessionVerificationControllerDelegate {
    private let forward: @Sendable (SessionVerificationControllerProxyAction) -> Void

    init(onAction: @escaping @MainActor (SessionVerificationControllerProxyAction) -> Void) {
        let listener = SDKListener<SessionVerificationControllerProxyAction>.onMainActor(onAction)
        forward = { listener.forward($0) }
    }

    // Requests started by other devices are out of scope (own-device SAS only).
    func didReceiveVerificationRequest(details: SessionVerificationRequestDetails) {}

    func didAcceptVerificationRequest() { forward(.acceptedVerificationRequest) }
    func didStartSasVerification() { forward(.startedSasVerification) }
    func didReceiveVerificationData(data: SessionVerificationData) { forward(.receivedVerificationData(VerificationData(rustData: data))) }
    func didFail() { forward(.failed) }
    func didCancel() { forward(.cancelled) }
    func didFinish() { forward(.finished) }
}
