//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
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

    @Test
    func tokenStoresDirectoryNamesResolvedAgainstTheCurrentContainer() throws {
        let token = try makeToken(withCryptoStore: false)

        let data = try JSONEncoder().encode(token)
        let decoded = try JSONDecoder().decode(RestorationToken.self, from: data)

        #expect(!String(decoding: data, as: UTF8.self).contains("Sessions"))
        #expect(decoded == token)
        #expect(decoded.sessionDirectories.dataDirectory.deletingLastPathComponent() == URL.sessionsBaseDirectory)
        #expect(decoded.sessionDirectories.cacheDirectory.deletingLastPathComponent() == URL.sessionCachesBaseDirectory)
    }

    @Test
    func legacyTokenWithAbsolutePathsFromAnotherContainerResolvesToTheCurrentOne() throws {
        let token = try makeToken(withCryptoStore: false)
        let oldContainer = URL(filePath: "/private/var/mobile/Containers/Data/Application/OLD-CONTAINER/Library")
        let legacy = LegacyRestorationToken(session: token.session,
                                            sessionDirectory: oldContainer.appending(path: "Application Support/Sessions/ABC"),
                                            cacheDirectory: oldContainer.appending(path: "Caches/Sessions/ABC"),
                                            passphrase: token.passphrase.base64EncodedString())

        let decoded = try JSONDecoder().decode(RestorationToken.self, from: JSONEncoder().encode(legacy))

        #expect(decoded.sessionDirectories == SessionDirectories(dataDirectoryName: "ABC", cacheDirectoryName: "ABC"))
        #expect(decoded.sessionDirectories.dataDirectory == URL.sessionsBaseDirectory.appending(component: "ABC"))
        #expect(decoded.sessionDirectories.cacheDirectory == URL.sessionCachesBaseDirectory.appending(component: "ABC"))
        #expect(decoded.passphrase == token.passphrase)
    }

    // MARK: - Helpers

    /// The token format from before directory names were stored instead of absolute URLs.
    private struct LegacyRestorationToken: Encodable {
        let session: Session
        let sessionDirectory: URL
        let cacheDirectory: URL
        let passphrase: String
    }

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
