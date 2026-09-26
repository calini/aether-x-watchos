//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK
import Security

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

final class QRLoginService: QRLoginServiceProtocol {
    private let clientFactory: ClientFactoryProtocol
    private let sessionStore: SessionStoreProtocol

    init(clientFactory: ClientFactoryProtocol, sessionStore: SessionStoreProtocol) {
        self.clientFactory = clientFactory
        self.sessionStore = sessionStore
    }

    func loginWithGeneratedQRCode(onProgress: @escaping @MainActor (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError> {
        let directories = SessionDirectories()
        let passphrase = Self.makePassphrase()
        // Only this attempt's own save should ever be cleared; an error before it must not touch an existing session.
        var didSaveSession = false
        // Set once the device exists server-side, so a late cancellation can still sign it out.
        var approvedClient: Client?

        do {
            try directories.create()
            let client = try await clientFactory.makeLoginClient(serverName: WatchAppSettings.defaultServerName,
                                                                   directories: directories,
                                                                   passphrase: passphrase)
            let handler = client.newLoginWithQrCodeHandler(oauthConfiguration: WatchAppSettings.oAuthConfiguration)
            let listener = SDKListener<GeneratedQrLoginProgress>.onMainActor { progress in
                if let progress = QRLoginProgress(progress) {
                    onProgress(progress)
                }
            }

            try await handler.generate(progressListener: listener)
            approvedClient = client
            try Task.checkCancellation()

            sessionStore.save(RestorationToken(session: try client.session(),
                                                sessionDirectories: directories,
                                                passphrase: passphrase,
                                                pusherNotificationClientIdentifier: nil))
            didSaveSession = true
            let userID = try client.userId()
            MXLog.info("QR login succeeded for \(userID)")
            return .success(try await ClientProxy.make(client: client))
        } catch let error as HumanQrLoginError {
            MXLog.error("QR login failed: \(error)")
            directories.delete()
            return .failure(QRLoginError(error))
        } catch is CancellationError {
            if let approvedClient {
                await Self.logOutAbandoned(approvedClient)
            }
            directories.delete()
            return .failure(.cancelled)
        } catch {
            MXLog.error("QR login failed unexpectedly: \(error)")
            if didSaveSession {
                // clear() already deletes the saved token's directories, which are this attempt's directories.
                sessionStore.clear()
            } else {
                directories.delete()
            }
            return .failure(.unknown)
        }
    }

    /// Best-effort: runs in its own task so the caller's cancellation doesn't cancel the request too.
    private static func logOutAbandoned(_ client: Client) async {
        MXLog.info("QR login cancelled after approval, signing the new device out")
        await Task {
            do {
                try await client.logout()
            } catch {
                MXLog.error("Signing out the abandoned QR login device failed: \(error)")
            }
        }.value
    }

    private static func makePassphrase() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            fatalError("Unable to generate a secure passphrase")
        }
        return Data(bytes)
    }
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
