//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import MatrixRustSDK

/// Lets the SDK read the session and persist refreshed OAuth tokens.
nonisolated final class SessionDelegate: ClientSessionDelegate {
    private let keychainStore: KeychainStoreProtocol

    init(keychainStore: KeychainStoreProtocol) {
        self.keychainStore = keychainStore
    }

    func retrieveSessionFromKeychain(userId: String) throws -> Session {
        guard let token = keychainStore.restorationToken(), token.session.userId == userId else {
            throw ClientError.Generic(msg: "No stored session for \(userId)", details: nil)
        }
        return token.session
    }

    func saveSessionInKeychain(session: Session) {
        // The initial save happens after login via SessionStore; nothing to refresh yet.
        // Another user's token must never be overwritten with this session.
        guard let token = keychainStore.restorationToken(), token.session.userId == session.userId else {
            return
        }
        MXLog.info("Saving refreshed session for \(session.userId)")
        keychainStore.setRestorationToken(RestorationToken(session: session,
                                                           sessionDirectories: token.sessionDirectories,
                                                           passphrase: token.passphrase,
                                                           pusherNotificationClientIdentifier: token.pusherNotificationClientIdentifier))
    }
}
