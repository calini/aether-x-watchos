//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum UserSessionRestorerError: Error {
    case noSession
    case restoreFailed
}

// sourcery: AutoMockable
protocol UserSessionRestorerProtocol {
    func restore() async -> Result<ClientProxyProtocol, UserSessionRestorerError>
}

final class UserSessionRestorer: UserSessionRestorerProtocol {
    private let sessionStore: SessionStoreProtocol
    private let clientFactory: ClientFactoryProtocol

    init(sessionStore: SessionStoreProtocol, clientFactory: ClientFactoryProtocol) {
        self.sessionStore = sessionStore
        self.clientFactory = clientFactory
    }

    func restore() async -> Result<ClientProxyProtocol, UserSessionRestorerError> {
        guard let token = sessionStore.restorationToken() else { return .failure(.noSession) }

        do {
            let client = try await clientFactory.makeRestoredClient(token: token)
            MXLog.info("Restored the session for \(token.session.userId)")
            return try await .success(ClientProxy.make(client: client))
        } catch {
            // Restoring is local (no discovery); a failure means the stored data is unusable.
            // Only the error type: enough to recognise a wrongful wipe on device, and never carries secrets.
            MXLog.error("Failed restoring the session with \(String(reflecting: type(of: error))), clearing it")
            sessionStore.clear()
            return .failure(.restoreFailed)
        }
    }
}
