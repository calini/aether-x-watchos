//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

// sourcery: AutoMockable
protocol SessionStoreProtocol {
    /// Whether a restorable session exists (token present and the crypto store still on disk).
    /// Checking this clears the session as a side effect if its crypto store is missing.
    var hasSession: Bool { get }
    /// The validated token, or `nil` (invalid sessions are cleared).
    /// A session whose crypto store is missing is cleared as a side effect of this call.
    func restorationToken() -> RestorationToken?
    func save(_ token: RestorationToken)
    /// Removes the token and deletes the session's files.
    func clear()
}

final class SessionStore: SessionStoreProtocol {
    private let keychainStore: KeychainStoreProtocol

    var hasSession: Bool {
        restorationToken() != nil
    }

    init(keychainStore: KeychainStoreProtocol) {
        self.keychainStore = keychainStore
    }

    func restorationToken() -> RestorationToken? {
        guard let token = keychainStore.restorationToken() else { return nil }

        // A token without its crypto store can't decrypt anything; start over instead of limping on.
        guard token.sessionDirectories.isNonTransientUserDataValid() else {
            MXLog.error("Crypto store missing for \(token.session.userId), clearing the session")
            clear(token)
            return nil
        }

        return token
    }

    func save(_ token: RestorationToken) {
        keychainStore.setRestorationToken(token)
    }

    func clear() {
        if let token = keychainStore.restorationToken() {
            clear(token)
        } else {
            keychainStore.removeRestorationToken()
        }
    }

    private func clear(_ token: RestorationToken) {
        keychainStore.removeRestorationToken()
        token.sessionDirectories.delete()
    }
}
