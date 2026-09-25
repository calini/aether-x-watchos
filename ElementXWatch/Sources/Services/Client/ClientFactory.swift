//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

// sourcery: AutoMockable
protocol ClientFactoryProtocol {
    func makeLoginClient(serverName: String, directories: SessionDirectories, passphrase: Data) async throws -> Client
    func makeRestoredClient(token: RestorationToken) async throws -> Client
}

/// Builds SDK clients whose HTTP traffic all goes through the given transport.
nonisolated struct ClientFactory: ClientFactoryProtocol {
    private let transport: HttpTransport
    private let sessionDelegate: ClientSessionDelegate

    init(transport: HttpTransport, sessionDelegate: ClientSessionDelegate) {
        self.transport = transport
        self.sessionDelegate = sessionDelegate
    }

    func makeLoginClient(serverName: String, directories: SessionDirectories, passphrase: Data) async throws -> Client {
        try await makeBaseBuilder()
            .slidingSyncVersionBuilder(versionBuilder: .discoverNative)
            .sqliteStore(config: .init(dataPath: directories.dataPath, cachePath: directories.cachePath)
                .highEntropyPassphrase(passphrase: passphrase, base64Variant: .padded))
            .serverNameOrHomeserverUrl(serverNameOrUrl: serverName)
            .build()
    }

    func makeRestoredClient(token: RestorationToken) async throws -> Client {
        let client = try await makeBaseBuilder()
            .sqliteStore(config: .init(dataPath: token.sessionDirectories.dataPath, cachePath: token.sessionDirectories.cachePath)
                .highEntropyPassphrase(passphrase: token.passphrase, base64Variant: .padded))
            .homeserverUrl(url: token.session.homeserverUrl)
            .build()
        try await client.restoreSessionWith(session: token.session, roomLoadSettings: .all)
        return client
    }

    private func makeBaseBuilder() -> ClientBuilder {
        var builder = ClientBuilder()
            .httpTransport(transport: transport)
            .setSessionDelegate(sessionDelegate: sessionDelegate)
            .userAgent(userAgent: WatchAppSettings.userAgent)
            .requestConfig(config: .init(retryLimit: 3, timeout: 30000, maxConcurrentRequests: 4, maxRetryTime: nil))
            .dmRoomDefinition(dmRoomDefinition: .twoMembers)
            .systemIsMemoryConstrained()
            .autoEnableCrossSigning(autoEnableCrossSigning: true)
            .backupDownloadStrategy(backupDownloadStrategy: .afterDecryptionFailure)
            .enableShareHistoryOnInvite(enableShareHistoryOnInvite: true)
            .autoEnableBackups(autoEnableBackups: true)
            .roomKeyRecipientStrategy(strategy: .errorOnVerifiedUserProblem)
            .decryptionSettings(decryptionSettings: .init(senderDeviceTrustRequirement: .untrusted))

        #if DEBUG
        // Tripwire: anything that bypasses the transport hits a closed port and fails loudly.
        builder = builder.proxy(url: "http://127.0.0.1:9")
        #endif

        return builder
    }
}
