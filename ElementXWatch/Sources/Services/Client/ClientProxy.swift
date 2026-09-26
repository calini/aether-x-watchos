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
    private let sendQueueErrorSubject = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()
    private var syncStateHandle: TaskHandle?
    private var sendQueueStatusHandle: TaskHandle?
    private var verificationStateHandle: TaskHandle?
    private var delegateHandle: TaskHandle?

    /// The SDK controller shares one delegate slot across every proxy built from it, so this is cached:
    /// a second proxy's `setDelegate` would silently steal callbacks from the first, and the first's
    /// `deinit` would then clear the second's delegate too.
    private var sessionVerificationControllerProxy: SessionVerificationControllerProxyProtocol?
    /// Serialises concurrent first calls onto the same fetch, so they can't each build a competing proxy.
    private var sessionVerificationControllerTask: Task<Result<SessionVerificationControllerProxyProtocol, Error>, Never>?
    private var hasLoggedSessionVerificationControllerFailure = false

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

        sendQueueStatusHandle = client.subscribeToSendQueueStatus(listener: SDKListener<(String, ClientError)>.onMainActor { [weak self] roomID, _ in
            MXLog.error("Send queue disabled after an error in \(roomID)")
            self?.sendQueueErrorSubject.send(())
        })
        observeSendQueues()

        delegateHandle = try client.setDelegate(delegate: ClientDelegateForwarder { [weak self] isSoftLogout in
            MXLog.error("Received an auth error (soft logout: \(isSoftLogout))")
            self?.actionsSubject.send(.authError(isSoftLogout: isSoftLogout))
        })
    }

    deinit {
        syncStateHandle?.cancel()
        sendQueueStatusHandle?.cancel()
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
        // Normally already started with the session; retries a start that failed then.
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

    func timelineProxy(for roomID: String) async -> TimelineProxyProtocol? {
        do {
            let roomListService = syncService.roomListService()
            // Subscribing gives the room full sliding-sync state while it's open.
            try await roomListService.setRoomSubscriptions(roomIds: [roomID])
            let room = try roomListService.room(roomId: roomID)
            let timeline = try await room.timeline()
            return TimelineProxy(timeline: timeline, ownUserID: userID) {
                room.enableSendQueue(enable: true)
            }
        } catch {
            MXLog.error("Failed opening the timeline for \(roomID): \(error)")
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

    func sessionVerificationController() async -> SessionVerificationControllerProxyProtocol? {
        if let sessionVerificationControllerProxy {
            return sessionVerificationControllerProxy
        }

        let task = sessionVerificationControllerTask ?? Task { [client, userID] () -> Result<SessionVerificationControllerProxyProtocol, Error> in
            do {
                return try await .success(SessionVerificationControllerProxy(controller: client.getSessionVerificationController()))
            } catch {
                // The controller needs the own identity, which is only in the store once a keys query has run
                // (e.g. not yet right after a fresh sign-in), so ask the server for it and try once more.
                guard (try? await client.encryption().userIdentity(userId: userID, fallbackToServer: true)) != nil else {
                    return .failure(error)
                }
                do {
                    return try await .success(SessionVerificationControllerProxy(controller: client.getSessionVerificationController()))
                } catch {
                    return .failure(error)
                }
            }
        }
        sessionVerificationControllerTask = task
        let result = await task.value
        sessionVerificationControllerTask = nil

        switch result {
        case .success(let proxy):
            sessionVerificationControllerProxy = proxy
            return proxy
        case .failure(let error):
            // Callers retry while the identity downloads, so only the first failure is logged.
            if !hasLoggedSessionVerificationControllerFailure {
                MXLog.error("Failed to get the session verification controller: \(error)")
                hasLoggedSessionVerificationControllerFailure = true
            }
            return nil
        }
    }

    /// Any send error disables that room's send queue until it's re-enabled (mirrors iOS): on every
    /// return to `.running`, and after an error that happened while running (debounced).
    private func observeSendQueues() {
        let running = syncStateSubject.removeDuplicates().filter { $0 == .running }.map { _ in () }
        let errorsWhileRunning = sendQueueErrorSubject
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .filter { [weak self] in self?.syncStateSubject.value == .running }

        running.merge(with: errorsWhileRunning)
            .sink { [client] in
                MXLog.info("Enabling all send queues")
                Task { await client.enableAllSendQueues(enable: true) }
            }
            .store(in: &cancellables)
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
