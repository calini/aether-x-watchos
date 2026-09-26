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

enum SyncState: Equatable {
    case idle
    case running
    case offline
    case error

    init(_ state: SyncServiceState) {
        switch state {
        case .idle, .terminated: self = .idle
        case .running: self = .running
        case .offline: self = .offline
        case .error: self = .error
        }
    }
}

enum SessionVerification: Equatable {
    case unknown
    case verified
    case unverified

    init(_ state: VerificationState) {
        switch state {
        case .unknown: self = .unknown
        case .verified: self = .verified
        case .unverified: self = .unverified
        }
    }
}

enum ClientProxyAction: Equatable {
    /// The homeserver rejected our token; the session must be cleared.
    case authError(isSoftLogout: Bool)
}

// sourcery: AutoMockable
protocol ClientProxyProtocol: AnyObject, Sendable {
    var userID: String { get }
    var deviceID: String? { get }
    var homeserver: String { get }
    var syncStatePublisher: AnyPublisher<SyncState, Never> { get }
    var verificationStatePublisher: AnyPublisher<SessionVerification, Never> { get }
    var actionsPublisher: AnyPublisher<ClientProxyAction, Never> { get }
    var roomSummaryProvider: RoomSummaryProviderProtocol { get }

    func startSync() async
    func stopSync() async
    func loadDisplayName() async -> String?
    func loadThumbnail(for source: MediaSourceProxy, width: Int, height: Int) async -> Data?
    func timelineProxy(for roomID: String) async -> TimelineProxyProtocol?
    func logout() async
    func sessionVerificationController() async -> SessionVerificationControllerProxyProtocol?
}
