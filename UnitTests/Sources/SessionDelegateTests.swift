//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite(.serialized)
struct SessionDelegateTests {
    @Test
    func retrievesTheStoredSession() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let token = try makeToken(withCryptoStore: false)
        keychain.setRestorationToken(token)
        let delegate = SessionDelegate(keychainStore: keychain)

        let session = try delegate.retrieveSessionFromKeychain(userId: "@alice:example.org")

        #expect(session.accessToken == "access")
    }

    @Test
    func refusesAnotherUsersSession() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        keychain.setRestorationToken(try makeToken(withCryptoStore: false))
        let delegate = SessionDelegate(keychainStore: keychain)

        #expect(throws: (any Error).self) {
            _ = try delegate.retrieveSessionFromKeychain(userId: "@bob:example.org")
        }
    }

    @Test
    func refreshedTokensAreSavedKeepingDirectoriesAndPassphrase() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let original = try makeToken(withCryptoStore: false)
        keychain.setRestorationToken(original)
        let delegate = SessionDelegate(keychainStore: keychain)
        var refreshed = original.session
        refreshed.accessToken = "new-access"

        delegate.saveSessionInKeychain(session: refreshed)

        let stored = try #require(keychain.restorationToken())
        #expect(stored.session.accessToken == "new-access")
        #expect(stored.sessionDirectories == original.sessionDirectories)
        #expect(stored.passphrase == original.passphrase)
    }

    @Test
    func anotherUsersRefreshedSessionDoesNotOverwriteTheStoredToken() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let original = try makeToken(withCryptoStore: false)
        keychain.setRestorationToken(original)
        let delegate = SessionDelegate(keychainStore: keychain)
        let other = try makeToken(withCryptoStore: false, userID: "@mallory:example.org")

        delegate.saveSessionInKeychain(session: other.session)

        #expect(keychain.restorationToken() == original)
    }
}
