//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

protocol CheckCodeSending: AnyObject, Sendable {
    func send(code: UInt8) async throws
}

extension CheckCodeSender: CheckCodeSending { }

enum QRLoginProgress {
    case starting
    /// The QR code bytes for the phone to scan.
    case showingQRCode(Data)
    /// The phone shows a 2-digit code that the user must enter.
    case enteringCheckCode(CheckCodeSending)
    /// Waiting for the user to approve on the phone.
    case waitingForApproval(userCode: String)
    case syncingSecrets

    init?(_ progress: GeneratedQrLoginProgress) {
        switch progress {
        case .starting: self = .starting
        case .qrReady(let qrCode): self = .showingQRCode(qrCode.toBytes())
        case .qrScanned(let sender): self = .enteringCheckCode(sender)
        case .waitingForToken(let userCode): self = .waitingForApproval(userCode: userCode)
        case .syncingSecrets: self = .syncingSecrets
        case .done: return nil // The app still has to set up the session.
        }
    }
}

enum QRLoginError: Error, Equatable {
    case expired
    case declined
    case cancelled
    case insecureConnection
    case linkingNotSupported
    case serverNotSupported
    case otherDeviceNotSignedIn
    case unknown

    init(_ error: HumanQrLoginError) {
        switch error {
        case .Expired: self = .expired
        case .Declined: self = .declined
        case .Cancelled: self = .cancelled
        case .ConnectionInsecure, .CheckCodeAlreadySent, .CheckCodeCannotBeSent: self = .insecureConnection
        case .LinkingNotSupported, .UnsupportedQrCodeType: self = .linkingNotSupported
        case .SlidingSyncNotAvailable, .OAuthMetadataInvalid, .NotFound: self = .serverNotSupported
        case .OtherDeviceNotSignedIn: self = .otherDeviceNotSignedIn
        case .Unknown, .ContinuationAlreadySent, .ContinuationCannotBeSent: self = .unknown
        }
    }

    var message: String {
        switch self {
        case .expired: WatchStrings.qrErrorExpired
        case .declined: WatchStrings.qrErrorDeclined
        case .cancelled: WatchStrings.qrErrorCancelled
        case .insecureConnection: WatchStrings.qrErrorInsecure
        case .linkingNotSupported: WatchStrings.qrErrorLinkingNotSupported
        case .serverNotSupported: WatchStrings.qrErrorServerNotSupported
        case .otherDeviceNotSignedIn: WatchStrings.qrErrorOtherDeviceNotSignedIn
        case .unknown: WatchStrings.qrErrorUnknown
        }
    }
}

// sourcery: AutoMockable
protocol QRLoginServiceProtocol {
    /// Runs the MSC4108 flow where this device shows the QR code. On success the session is saved.
    func loginWithGeneratedQRCode(onProgress: @escaping @MainActor (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError>
}

extension QRLoginProgress: CustomStringConvertible {
    /// Case-name-only description; keeps the QR bytes and check-code sender out of the logs.
    var description: String {
        switch self {
        case .starting: "starting"
        case .showingQRCode: "showingQRCode"
        case .enteringCheckCode: "enteringCheckCode"
        case .waitingForApproval: "waitingForApproval"
        case .syncingSecrets: "syncingSecrets"
        }
    }
}
