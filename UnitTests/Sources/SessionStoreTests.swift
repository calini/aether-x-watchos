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
struct SessionStoreTests {
    @Test
    func noTokenMeansNoSession() {
        let (store, _) = makeStore()
        #expect(!store.hasSession)
        #expect(store.restorationToken() == nil)
    }

    @Test
    func savedTokenWithCryptoStoreIsASession() throws {
        let (store, _) = makeStore()
        let token = try makeToken(withCryptoStore: true)

        store.save(token)

        #expect(store.hasSession)
        #expect(store.restorationToken() == token)
    }

    @Test
    func tokenWithoutCryptoStoreIsDiscarded() throws {
        let (store, keychain) = makeStore()
        let token = try makeToken(withCryptoStore: false)
        store.save(token)

        #expect(!store.hasSession)
        #expect(store.restorationToken() == nil)
        #expect(keychain.restorationToken() == nil)
        #expect(!FileManager.default.fileExists(atPath: token.sessionDirectories.dataPath))
    }

    @Test
    func clearRemovesTokenAndFiles() throws {
        let (store, keychain) = makeStore()
        let token = try makeToken(withCryptoStore: true)
        store.save(token)

        store.clear()

        #expect(keychain.restorationToken() == nil)
        #expect(!FileManager.default.fileExists(atPath: token.sessionDirectories.dataPath))
        #expect(!FileManager.default.fileExists(atPath: token.sessionDirectories.cachePath))
    }

    @Test
    func tokenRoundTripsThroughTheKeychain() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let token = try makeToken(withCryptoStore: false)

        keychain.setRestorationToken(token)
        #expect(keychain.restorationToken() == token)

        keychain.removeRestorationToken()
        #expect(keychain.restorationToken() == nil)
    }

    // MARK: - Helpers

    private func makeStore() -> (SessionStore, KeychainStore) {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        return (SessionStore(keychainStore: keychain), keychain)
    }
}

func makeToken(withCryptoStore: Bool, userID: String = "@alice:example.org") throws -> RestorationToken {
    let directories = SessionDirectories()
    try directories.create()
    if withCryptoStore {
        FileManager.default.createFile(atPath: directories.dataPath + "/matrix-sdk-crypto.sqlite3", contents: Data())
    }
    return RestorationToken(session: Session(accessToken: "access",
                                             refreshToken: "refresh",
                                             userId: userID,
                                             deviceId: "DEVICE",
                                             homeserverUrl: "https://matrix-client.example.org",
                                             oauthData: nil,
                                             slidingSyncVersion: .native),
                            sessionDirectories: directories,
                            passphrase: Data("passphrase".utf8),
                            pusherNotificationClientIdentifier: nil)
}
