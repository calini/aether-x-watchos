//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

/// The watch's wrapper around the SDK `Client`, slimmed from iOS's ClientProxy to DMs and groups.
final class ClientProxy: ClientProxyProtocol {
    private let client: Client
    private let syncService: SyncService
    private let syncStateSubject = CurrentValueSubject<SyncState, Never>(.idle)
    private let verificationStateSubject = CurrentValueSubject<SessionVerification, Never>(.unknown)
    private let actionsSubject = PassthroughSubject<ClientProxyAction, Never>()

    private var syncStateHandle: TaskHandle?
    private var verificationStateHandle: TaskHandle?
    private var delegateHandle: TaskHandle?

    let userID: String
    let deviceID: String?
    let roomSummaryProvider: RoomSummaryProviderProtocol

    var homeserver: String { client.homeserver() }
    var syncStatePublisher: AnyPublisher<SyncState, Never> { syncStateSubject.removeDuplicates().eraseToAnyPublisher() }
    var verificationStatePublisher: AnyPublisher<SessionVerification, Never> { verificationStateSubject.removeDuplicates().eraseToAnyPublisher() }
    var actionsPublisher: AnyPublisher<ClientProxyAction, Never> { actionsSubject.eraseToAnyPublisher() }

    private init(client: Client, syncService: SyncService) throws {
        self.client = client
        self.syncService = syncService
        userID = try client.userId()
        deviceID = try? client.deviceId()
        roomSummaryProvider = RoomSummaryProvider(roomListService: syncService.roomListService())

        syncStateHandle = syncService.state(listener: SDKListener<SyncServiceState>.onMainActor { [weak self] state in
            MXLog.info("Sync state: \(state)")
            self?.syncStateSubject.send(SyncState(state))
        })

        let encryption = client.encryption()
        verificationStateSubject.send(SessionVerification(encryption.verificationState()))
        verificationStateHandle = encryption.verificationStateListener(listener: SDKListener<VerificationState>.onMainActor { [weak self] state in
            self?.verificationStateSubject.send(SessionVerification(state))
        })

        delegateHandle = try client.setDelegate(delegate: ClientDelegateForwarder { [weak self] isSoftLogout in
            MXLog.error("Received an auth error (soft logout: \(isSoftLogout))")
            self?.actionsSubject.send(.authError(isSoftLogout: isSoftLogout))
        })
    }

    deinit {
        syncStateHandle?.cancel()
        verificationStateHandle?.cancel()
        delegateHandle?.cancel()
    }

    static func make(client: Client) async throws -> ClientProxy {
        let syncService = try await client.syncService().withOfflineMode().finish()
        return try ClientProxy(client: client, syncService: syncService)
    }

    func startSync() async {
        MXLog.info("Starting sync")
        await syncService.start()
        await roomSummaryProvider.start()
    }

    func stopSync() async {
        MXLog.info("Stopping sync")
        await syncService.stop()
    }

    func loadDisplayName() async -> String? {
        try? await client.displayName()
    }

    func loadThumbnail(for source: MediaSourceProxy, width: Int, height: Int) async -> Data? {
        do {
            return try await client.getMediaThumbnail(mediaSource: source.source, width: UInt64(width), height: UInt64(height))
        } catch {
            MXLog.error("Failed loading a thumbnail: \(error)")
            return nil
        }
    }

    func logout() async {
        await syncService.stop()
        do {
            try await client.logout()
        } catch {
            MXLog.error("Logout request failed, clearing the session anyway: \(error)")
        }
    }
}

/// Forwards the SDK's client delegate callbacks onto the main actor.
private nonisolated final class ClientDelegateForwarder: ClientDelegate {
    private let onAuthError: @Sendable (Bool) -> Void

    init(onAuthError: @escaping @MainActor (Bool) -> Void) {
        let listener = SDKListener<Bool>.onMainActor(onAuthError)
        self.onAuthError = { listener.forward($0) }
    }

    func didReceiveAuthError(isSoftLogout: Bool) {
        onAuthError(isSoftLogout)
    }

    func onBackgroundTaskErrorReport(taskName: String, error: BackgroundTaskFailureReason) {
        MXLog.error("Background task \(taskName) failed: \(error)")
    }
}
