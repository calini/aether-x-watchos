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

struct LoginOptions: Hashable {
    let serverName: String
    let supportsPassword: Bool
    let supportsQRCode: Bool

    var supportsAnyMethod: Bool {
        supportsPassword || supportsQRCode
    }
}

enum AuthenticationError: Error, Equatable {
    case serverUnreachable
    case serverNotSupported
    case invalidCredentials
    case rateLimited
    case unknown

    var message: String {
        switch self {
        case .serverUnreachable: WatchStrings.serverUnreachable
        case .serverNotSupported: WatchStrings.serverNotSupported
        case .invalidCredentials: WatchStrings.wrongCredentials
        case .rateLimited: WatchStrings.rateLimited
        case .unknown: WatchStrings.signInFailed
        }
    }

    init(loginError: Error) {
        guard case .MatrixApi(let kind, _, _, _) = loginError as? ClientError else {
            self = .unknown
            return
        }
        switch kind {
        case .forbidden: self = .invalidCredentials
        case .limitExceeded: self = .rateLimited
        default: self = .unknown
        }
    }
}

// sourcery: AutoMockable
protocol AuthenticationServiceProtocol {
    /// Builds a login client for `server` (a server name or URL) and reports how the user can sign in.
    func configure(server: String) async -> Result<LoginOptions, AuthenticationError>
    /// Password login on the configured server. On success the session is saved.
    func login(username: String, password: String) async -> Result<ClientProxyProtocol, AuthenticationError>
    /// Abandons the configured server, deleting its not-yet-used session files.
    func reset()
}

/// The login client for the chosen server. Its directories become the session's once login succeeds.
private struct PendingLogin {
    let client: Client
    let directories: SessionDirectories
    let passphrase: Data
}

final class AuthenticationService: AuthenticationServiceProtocol, QRLoginServiceProtocol {
    private static let deviceName = "Element X Watch"

    private let clientFactory: ClientFactoryProtocol
    private let sessionStore: SessionStoreProtocol
    private var pendingLogin: PendingLogin?
    private var lastServer: String?
    /// Bumped by every `reset()` (including the implicit one at the top of `configure`), so an
    /// in-flight `configure` or pending-login rebuild can tell, after an `await`, that a newer call or an
    /// explicit `reset()` superseded it and its own client/directories must be thrown away instead of adopted.
    private var generation = 0

    init(clientFactory: ClientFactoryProtocol, sessionStore: SessionStoreProtocol) {
        self.clientFactory = clientFactory
        self.sessionStore = sessionStore
    }

    func configure(server: String) async -> Result<LoginOptions, AuthenticationError> {
        reset()
        let myGeneration = generation
        lastServer = server

        let pending: PendingLogin
        switch await makePendingLogin(server: server) {
        case .success(let login): pending = login
        case .failure(let error): return .failure(error)
        }
        guard myGeneration == generation else {
            // Superseded by a reset() or another configure() while awaiting above: this attempt's
            // directories are its own (never adopted by anyone else), so they're safe to delete here.
            pending.directories.delete()
            return .failure(.unknown)
        }
        pendingLogin = pending

        let details = await pending.client.homeserverLoginDetails()
        let supportsQRCode = (try? await pending.client.isLoginWithQrCodeSupported()) ?? false
        guard myGeneration == generation else {
            pending.directories.delete()
            return .failure(.unknown)
        }

        let serverName = (try? pending.client.userIdServerName()) ?? URL(string: details.url())?.host() ?? server
        return .success(LoginOptions(serverName: serverName,
                                     supportsPassword: details.supportsPasswordLogin(),
                                     supportsQRCode: supportsQRCode))
    }

    func login(username: String, password: String) async -> Result<ClientProxyProtocol, AuthenticationError> {
        guard let pending = await ensurePendingLogin() else { return .failure(.unknown) }
        let myGeneration = generation

        do {
            try await pending.client.login(username: username, password: password, initialDeviceName: Self.deviceName, deviceId: nil)
        } catch {
            MXLog.error("Password login failed: \(error)")
            return .failure(AuthenticationError(loginError: error))
        }
        guard myGeneration == generation else {
            // reset() or configure() ran meanwhile and deleted this client's directories: don't save a broken session.
            await Self.logOutAbandoned(pending.client)
            return .failure(.unknown)
        }

        return await finishLogin(pending)
            .mapError { _ in AuthenticationError.unknown }
    }

    func reset() {
        generation += 1
        pendingLogin?.directories.delete()
        pendingLogin = nil
    }

    // Body moved verbatim from the old QRLoginService, except that it uses the pending login
    // (re-created for the last server if a previous attempt consumed it).
    func loginWithGeneratedQRCode(onProgress: @escaping @MainActor (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError> {
        guard let pending = await ensurePendingLogin() else { return .failure(.unknown) }
        pendingLogin = nil // This attempt owns the directories from here on.

        // Set once the device exists server-side, so a late cancellation can still sign it out.
        var approvedClient: Client?
        do {
            let handler = pending.client.newLoginWithQrCodeHandler(oauthConfiguration: WatchAppSettings.oAuthConfiguration)
            let listener = SDKListener<GeneratedQrLoginProgress>.onMainActor { progress in
                if let progress = QRLoginProgress(progress) {
                    onProgress(progress)
                }
            }
            try await handler.generate(progressListener: listener)
            approvedClient = pending.client
            try Task.checkCancellation()
            return await finishLogin(pending).mapError { _ in QRLoginError.unknown }
        } catch let error as HumanQrLoginError {
            MXLog.error("QR login failed: \(error)")
            pending.directories.delete()
            return .failure(QRLoginError(error))
        } catch is CancellationError {
            if let approvedClient {
                await Self.logOutAbandoned(approvedClient)
            }
            pending.directories.delete()
            return .failure(.cancelled)
        } catch {
            MXLog.error("QR login failed unexpectedly: \(error)")
            pending.directories.delete()
            return .failure(.unknown)
        }
    }

    /// The pending login, re-created for the last server when a QR attempt consumed it.
    private func ensurePendingLogin() async -> PendingLogin? {
        if let pendingLogin { return pendingLogin }
        let myGeneration = generation
        let server = lastServer ?? WatchAppSettings.defaultServerName
        guard case .success(let login) = await makePendingLogin(server: server) else { return nil }
        guard myGeneration == generation else {
            // A reset() or configure() ran meanwhile and wins: these directories were never adopted.
            login.directories.delete()
            return nil
        }
        if let pendingLogin {
            // A concurrent rebuild got there first.
            login.directories.delete()
            return pendingLogin
        }
        pendingLogin = login
        return login
    }

    private func makePendingLogin(server: String) async -> Result<PendingLogin, AuthenticationError> {
        let directories = SessionDirectories()
        let passphrase = Self.makePassphrase()
        do {
            try directories.create()
            let client = try await clientFactory.makeLoginClient(serverName: server, directories: directories, passphrase: passphrase)
            return .success(PendingLogin(client: client, directories: directories, passphrase: passphrase))
        } catch {
            MXLog.error("Configuring server \(server) failed: \(error)")
            directories.delete()
            return .failure(Self.configurationError(error))
        }
    }

    /// Saves the session and wraps the client. Only this attempt's save is ever cleared on failure.
    private func finishLogin(_ pending: PendingLogin) async -> Result<ClientProxyProtocol, Error> {
        var didSaveSession = false
        do {
            sessionStore.save(RestorationToken(session: try pending.client.session(),
                                               sessionDirectories: pending.directories,
                                               passphrase: pending.passphrase,
                                               pusherNotificationClientIdentifier: nil))
            didSaveSession = true
            if pendingLogin?.directories == pending.directories { pendingLogin = nil }
            let userID = try pending.client.userId()
            MXLog.info("Signed in as \(userID)")
            return .success(try await ClientProxy.make(client: pending.client))
        } catch {
            MXLog.error("Finishing sign-in failed: \(error)")
            if didSaveSession {
                // clear() already deletes the saved token's directories, which are this attempt's.
                sessionStore.clear()
            } else {
                pending.directories.delete()
            }
            if pendingLogin?.directories == pending.directories { pendingLogin = nil }
            return .failure(error)
        }
    }

    /// Best-effort: runs in its own task so the caller's cancellation doesn't cancel the request too.
    private static func logOutAbandoned(_ client: Client) async {
        MXLog.info("Sign-in abandoned after the device was created, signing it out")
        await Task {
            do {
                try await client.logout()
            } catch {
                MXLog.error("Signing out the abandoned device failed: \(error)")
            }
        }.value
    }

    private static func configurationError(_ error: Error) -> AuthenticationError {
        if let buildError = error as? ClientBuildError, case .SlidingSyncVersion = buildError {
            return .serverNotSupported
        }
        return .serverUnreachable
    }

    private static func makePassphrase() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            fatalError("Unable to generate a secure passphrase")
        }
        return Data(bytes)
    }
}
