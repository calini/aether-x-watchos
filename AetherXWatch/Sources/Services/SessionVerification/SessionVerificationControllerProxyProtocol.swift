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

struct VerificationEmoji: Hashable, Identifiable, Sendable {
    let symbol: String
    let description: String

    var id: String {
        symbol + description
    }
}

enum VerificationData: Equatable, Sendable {
    case emojis([VerificationEmoji])
    case decimals([UInt16])

    /// Pure mapping, called from the SDK's `nonisolated` delegate forwarder off the main actor.
    nonisolated init(rustData: SessionVerificationData) {
        switch rustData {
        case .emojis(let emojis, _):
            self = .emojis(emojis.map { VerificationEmoji(symbol: $0.symbol(), description: $0.description()) })
        case .decimals(let values):
            self = .decimals(values)
        }
    }
}

enum SessionVerificationControllerProxyAction: Equatable, Sendable {
    case acceptedVerificationRequest
    case startedSasVerification
    case receivedVerificationData(VerificationData)
    case finished
    case cancelled
    case failed
}

extension SessionVerificationControllerProxyAction: CustomStringConvertible {
    // Only the case name is logged: `receivedVerificationData` carries emoji values.
    var description: String {
        switch self {
        case .acceptedVerificationRequest: "acceptedVerificationRequest"
        case .startedSasVerification: "startedSasVerification"
        case .receivedVerificationData: "receivedVerificationData"
        case .finished: "finished"
        case .cancelled: "cancelled"
        case .failed: "failed"
        }
    }
}

enum SessionVerificationControllerProxyError: Error {
    case failedRequestingVerification
    case failedStartingSasVerification
    case failedApprovingVerification
    case failedDecliningVerification
    case failedCancellingVerification
}

// sourcery: AutoMockable
protocol SessionVerificationControllerProxyProtocol: AnyObject, Sendable {
    var actionsPublisher: AnyPublisher<SessionVerificationControllerProxyAction, Never> { get }

    /// Asks this account's other devices to verify this one.
    func requestDeviceVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    func startSasVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    func approveVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    func declineVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    func cancelVerification() async -> Result<Void, SessionVerificationControllerProxyError>
}
