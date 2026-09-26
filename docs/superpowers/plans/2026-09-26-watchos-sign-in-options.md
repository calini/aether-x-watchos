# Element X watchOS — Sub-project 1.1 Implementation Plan (server choice, password sign-in, emoji verification)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user pick a homeserver (default `matrix.org`), then sign in with a password or a QR code (as the server allows), and optionally verify a password sign-in by comparing emojis with another device.

**Architecture:**
- A new `AuthenticationService` owns a *pending login*: a login client for the chosen server, with its own session directories and passphrase. It reports the server's login options, performs password login, and runs the existing MSC4108 QR flow on that same client.
- `AuthenticationFlowCoordinator` becomes a `NavigationStack`: server → method → password | QR.
- A `SessionVerificationControllerProxy` wraps the SDK's SAS verification. A skippable verification sheet is shown over Chats after a password sign-in and can be opened from Settings while the watch is unverified.

**Tech Stack:** Swift 6.2 / SwiftUI / watchOS 11, `MatrixRustSDK` (local package from the SDK fork), Swift Testing, Sourcery, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-26-watchos-sign-in-options-design.md`. Read it first. It builds on `docs/superpowers/specs/2026-09-25-watchos-client-design.md`.

## Global Constraints

- Repo: `~/Developer/git/github.com/element-hq/element-x-watchos`, branch `sub-project-1`. **The SDK fork is not changed in this sub-project.** element-x-ios is read-only reference.
- The default server is `WatchAppSettings.defaultServerName` (`"matrix.org"`), used only to prefill the server field.
- The password-login initial device name is `"Element X Watch"`. Never log passwords, tokens or emoji values. Server names and Matrix IDs are fine.
- Verification after a password sign-in is **skippable** ("Not now" goes to the chats), and the QR sign-in path never shows verification.
- Every screen follows MVVM-C: `…ScreenModels.swift`, `…ScreenViewModelProtocol.swift`, `…ScreenViewModel.swift` (`StateStoreViewModelV2`), `…ScreenCoordinator.swift`, `View/…Screen.swift`. Every screen gets a `PreviewProvider` covering every main state.
- Strings go in `WatchStrings` (a `nonisolated enum`). Styling uses `Color.compound` and system controls. Text inputs are standard SwiftUI `TextField`/`SecureField` (watchOS input sheet, so iPhone remote typing works).
- App target: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Never add `@unchecked Sendable` / `nonisolated(unsafe)` by hand. SDK callbacks arrive on background threads; forward them to the main actor (the existing `SDKListener.onMainActor` pattern, or a `nonisolated` forwarder like `ClientDelegateForwarder` in `ClientProxy.swift`).
- Licence headers:
  - files derived from element-x-ios keep the ORIGINAL element-x-ios copyright block verbatim, and each gets a row in `SHARED_FROM_IOS.md`;
  - watch-authored files use the single-line header from `ElementXWatch/Sources/Application/ElementXWatchApp.swift`.
- Member order: properties (stored and computed) → `init`/`deinit` → functions. Views: properties → `init` → `body` → other views → functions.
- Sourcery mock names drop the `Protocol` suffix, for example `AuthenticationServiceProtocol` → `AuthenticationServiceMock`. Mocks regenerate at build time into `ElementXWatch/Sources/Mocks/Generated/GeneratedMocks.swift`; commit that file.
- Shared test helpers live in `UnitTests/Sources/Support/`:
  - `TestHelpers.swift`: `waitUntil`, `AsyncGate`;
  - `TestFixtures.swift`: `Setup`, fixtures;
  - `StubURLProtocol.swift`;
  - `SDKFixtures.swift`.
  Watchos simulators don't route PUT/POST through `URLProtocol`, so stubbed network tests may only use GET.
- Standard test command (run `xcodegen` first when files are added):
  ```bash
  cd ~/Developer/git/github.com/element-hq/element-x-watchos
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/opt/homebrew/bin:$PATH
  xcodegen -q && xcodebuild test -project ElementXWatch.xcodeproj -scheme ElementXWatch \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5' -parallel-testing-enabled NO 2>&1 | tail -30
  ```
  Output must be pristine: zero `warning:` lines from `ElementXWatch/Sources` or `UnitTests/Sources`, no no-op `await`s, no disabled tests.
- Commits: a title and a description, ending with `Co-Authored-By: <the model that wrote the commit> <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX`.

## Review Focus

1. **Server input with whitespace, `https://`, or uppercase** (`" Matrix.org "`, `"https://matrix.org"`). Expected: trimmed and accepted, with no confusing error. Pinned in Task 2 (`ServerSelectionScreenViewModelTests.trimsInput`).
2. **Wrong password.** Expected: "Wrong username or password.", the username kept, the password cleared, and the user can retry without choosing the server again. Pinned in Task 3.
3. **Going back from the method screen to change server.** Expected: the previous pending login's session directories are deleted, with no orphaned stores. Pinned in Task 4 (`AuthenticationFlowCoordinatorTests.backToServerResetsPendingLogin`).
4. **Verification cancelled or failing on the phone side.** Expected: the watch shows "Verification was cancelled."/"Verification failed." with Try again / Not now, never a spinner stuck forever. Pinned in Task 6.
5. **"Not now" after a password sign-in.** Expected: chats usable; Settings shows "Verify this watch" while unverified, and the row disappears once verified. Pinned in Task 7.

---

### Task 1: `AuthenticationService` (server configuration, password login, QR on the chosen server)

**Files:**
- Create: `ElementXWatch/Sources/Services/Authentication/AuthenticationService.swift` (derived from element-x-ios `ElementX/Sources/Services/Authentication/AuthenticationService.swift`: keep its copyright header and add a `SHARED_FROM_IOS.md` row)
- Modify: `ElementXWatch/Sources/Services/Authentication/QRLoginService.swift`:
  - keep `CheckCodeSending`, `QRLoginProgress`, `QRLoginError` and `QRLoginServiceProtocol`;
  - **delete the `QRLoginService` class** (its logic moves into `AuthenticationService`).
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Modify: `ElementXWatch/Sources/Application/ElementXWatchApp.swift` (construct `AuthenticationService` and pass it where `QRLoginService` was)
- Test: `UnitTests/Sources/AuthenticationServiceTests.swift`

**Interfaces:**
- Consumes:
  - `ClientFactoryProtocol.makeLoginClient(serverName:directories:passphrase:) async throws -> Client`;
  - `SessionStoreProtocol.save(_:)` / `clear()`, `SessionDirectories()`, `RestorationToken(...)`;
  - `ClientProxy.make(client:)`, `SDKListener`;
  - `WatchAppSettings.oAuthConfiguration`.
- Produces:
  ```swift
  struct LoginOptions: Hashable { let serverName: String; let supportsPassword: Bool; let supportsQRCode: Bool; var supportsAnyMethod: Bool }
  enum AuthenticationError: Error, Equatable { case serverUnreachable, serverNotSupported, invalidCredentials, rateLimited, unknown
      init(loginError: Error); var message: String }
  // sourcery: AutoMockable
  protocol AuthenticationServiceProtocol {
      func configure(server: String) async -> Result<LoginOptions, AuthenticationError>
      func login(username: String, password: String) async -> Result<ClientProxyProtocol, AuthenticationError>
      func reset()
  }
  final class AuthenticationService: AuthenticationServiceProtocol, QRLoginServiceProtocol { init(clientFactory: ClientFactoryProtocol, sessionStore: SessionStoreProtocol) }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/AuthenticationServiceTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite(.serialized)
struct AuthenticationServiceTests {
    @Test
    func configureReportsPasswordOnlyForAPasswordServer() async throws {
        StubURLProtocol.install { request, _ in Self.homeserver(request, loginTypes: ["m.login.password"], msc4108: false) }
        let service = makeService()

        let options = try await service.configure(server: "https://example.org").get()

        #expect(options.supportsPassword)
        #expect(!options.supportsQRCode)
        #expect(options.supportsAnyMethod)
        #expect(options.serverName == "example.org")
        service.reset()
    }

    @Test
    func configureReportsNoMethodsWhenThereAreNone() async throws {
        StubURLProtocol.install { request, _ in Self.homeserver(request, loginTypes: [], msc4108: false) }
        let service = makeService()

        let options = try await service.configure(server: "https://example.org").get()

        #expect(!options.supportsAnyMethod)
        service.reset()
    }

    @Test
    func unreachableServersAreReported() async {
        StubURLProtocol.install { _, _ in throw URLError(.cannotFindHost) }
        let service = makeService()

        let result = await service.configure(server: "https://nowhere.invalid")

        #expect(result == .failure(.serverUnreachable))
    }

    @Test
    func loginErrorsMapToUserFacingCases() {
        #expect(AuthenticationError(loginError: ClientError.MatrixApi(kind: .forbidden, code: "M_FORBIDDEN", msg: "x", details: nil)) == .invalidCredentials)
        #expect(AuthenticationError(loginError: ClientError.MatrixApi(kind: .limitExceeded(retryAfterMs: nil), code: "M_LIMIT_EXCEEDED", msg: "x", details: nil)) == .rateLimited)
        #expect(AuthenticationError(loginError: ClientError.Generic(msg: "boom", details: nil)) == .unknown)
        #expect(!AuthenticationError.invalidCredentials.message.isEmpty)
    }

    @Test
    func loginWithoutConfigureFails() async {
        let service = makeService()
        let result = await service.login(username: "alice", password: "secret")
        #expect(result.failureValue == .unknown)
    }

    // MARK: - Helpers

    private func makeService() -> AuthenticationService {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let factory = ClientFactory(transport: URLSessionTransport(configuration: StubURLProtocol.configuration()),
                                    sessionDelegate: SessionDelegate(keychainStore: keychain))
        return AuthenticationService(clientFactory: factory, sessionStore: SessionStore(keychainStore: keychain))
    }

    private static func homeserver(_ request: URLRequest, loginTypes: [String], msc4108: Bool) -> (HTTPURLResponse, Data) {
        let json: String
        switch request.url?.path() {
        case "/_matrix/client/versions":
            json = #"{"versions":["v1.11"],"unstable_features":{"org.matrix.simplified_msc3575":true,"org.matrix.msc4108":\#(msc4108)}}"#
        case "/_matrix/client/v3/login":
            json = #"{"flows":[\#(loginTypes.map { #"{"type":"\#($0)"}"# }.joined(separator: ","))]}"#
        default:
            return (.stub(request.url, status: 404), Data(#"{"errcode":"M_UNRECOGNIZED","error":"Unrecognized"}"#.utf8))
        }
        return (.stub(request.url, status: 200, headers: ["Content-Type": "application/json"]), Data(json.utf8))
    }
}

private extension Result {
    var failureValue: Failure? {
        if case .failure(let error) = self { error } else { nil }
    }
}
```

`Result<ClientProxyProtocol, AuthenticationError>` isn't `Equatable`, which is why the last test uses `failureValue`. Match the generated `ErrorKind.limitExceeded` label (`retryAfterMs`) and the `ClientError` case labels in `Packages/MatrixRustSDK/Sources/MatrixRustSDK/matrix_sdk_ffi.swift`.

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard command with `-only-testing:UnitTests/AuthenticationServiceTests`. Expected: build failure `cannot find 'AuthenticationService' in scope`.

- [ ] **Step 3: Implement**

Add to `WatchStrings`:

```swift
    static let serverUnreachable = "Couldn't reach this server."
    static let serverNotSupported = "This server isn't supported."
    static let wrongCredentials = "Wrong username or password."
    static let rateLimited = "Too many attempts. Try again later."
    static let signInFailed = "Couldn't sign in. Try again."
```

Change the existing `qrErrorServerNotSupported` to `"This server doesn't support signing in with a QR code."`.

`AuthenticationService.swift` (header copied from the iOS source file; the body is watch-specific):

```swift
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
    let server: String
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

    init(clientFactory: ClientFactoryProtocol, sessionStore: SessionStoreProtocol) {
        self.clientFactory = clientFactory
        self.sessionStore = sessionStore
    }

    func configure(server: String) async -> Result<LoginOptions, AuthenticationError> {
        reset()
        lastServer = server

        let pending: PendingLogin
        switch await makePendingLogin(server: server) {
        case .success(let login): pending = login
        case .failure(let error): return .failure(error)
        }
        pendingLogin = pending

        let details = await pending.client.homeserverLoginDetails()
        let supportsQRCode = (try? await pending.client.isLoginWithQrCodeSupported()) ?? false
        let serverName = (try? pending.client.userIdServerName()) ?? URL(string: details.url())?.host() ?? server
        return .success(LoginOptions(serverName: serverName,
                                     supportsPassword: details.supportsPasswordLogin(),
                                     supportsQRCode: supportsQRCode))
    }

    func login(username: String, password: String) async -> Result<ClientProxyProtocol, AuthenticationError> {
        guard let pending = pendingLogin else { return .failure(.unknown) }

        do {
            try await pending.client.login(username: username, password: password, initialDeviceName: Self.deviceName, deviceId: nil)
        } catch {
            MXLog.error("Password login failed: \(type(of: error))")
            return .failure(AuthenticationError(loginError: error))
        }

        return await finishLogin(pending)
            .mapError { _ in AuthenticationError.unknown }
    }

    func reset() {
        pendingLogin?.directories.delete()
        pendingLogin = nil
    }

    // Body moved verbatim from the old QRLoginService, except that it uses the pending login
    // (re-created for the last server if a previous attempt consumed it).
    func loginWithGeneratedQRCode(onProgress: @escaping @MainActor (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError> {
        if pendingLogin == nil, let lastServer, case .success(let login) = await makePendingLogin(server: lastServer) {
            pendingLogin = login
        }
        guard let pending = pendingLogin else { return .failure(.unknown) }
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
            MXLog.error("QR login failed unexpectedly: \(type(of: error))")
            pending.directories.delete()
            return .failure(.unknown)
        }
    }

    private func makePendingLogin(server: String) async -> Result<PendingLogin, AuthenticationError> {
        let directories = SessionDirectories()
        let passphrase = Self.makePassphrase()
        do {
            try directories.create()
            let client = try await clientFactory.makeLoginClient(serverName: server, directories: directories, passphrase: passphrase)
            return .success(PendingLogin(server: server, client: client, directories: directories, passphrase: passphrase))
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
            MXLog.error("Finishing sign-in failed: \(type(of: error))")
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
        MXLog.info("QR login cancelled after approval, signing the new device out")
        await Task {
            do {
                try await client.logout()
            } catch {
                MXLog.error("Signing out the abandoned QR login device failed: \(error)")
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
```

Adapt to the generated SDK names:
- the `ClientBuildError` case that means "no sliding sync" (look for `SlidingSyncVersion` or similar in `matrix_sdk_ffi.swift`; if there's none, map any build error to `.serverUnreachable` and say so in the report);
- `HomeserverLoginDetails.url()`;
- `Client.userIdServerName()` (it may throw before login; the fallback chain handles that).

Keep every behaviour from the old `QRLoginService`, including the ones pinned by existing tests and reviews:
- clear only this attempt's own save;
- log out an approved-but-cancelled device;
- log error *types* only, never content.

In `ElementXWatchApp.init`, replace `QRLoginService(clientFactory:sessionStore:)` with a single `let authenticationService = AuthenticationService(clientFactory: clientFactory, sessionStore: sessionStore)`, and pass it as the `qrLoginService:` argument for now. Task 4 adds the dedicated parameter.

- [ ] **Step 4: Run the tests to verify they pass**

Run the standard command (full suite). Expected: all existing tests plus `AuthenticationServiceTests` (5) pass, and QR tests are unaffected.

- [ ] **Step 5: Commit**

Add a row to `SHARED_FROM_IOS.md`: `| ElementXWatch/Sources/Services/Authentication/AuthenticationService.swift | ElementX/Sources/Services/Authentication/AuthenticationService.swift | Server configuration + password login + MSC4108 generate flow on one pending login client; no OAuth web flow, account providers or classic-app account. |`.

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Add an authentication service for server choice and password sign-in

Configures a login client for the chosen server, reports whether it
supports password and QR sign-in, performs password login and runs the
existing QR flow on the same client. Replaces the QR-only service."
```
(plus the trailers)

---

### Task 2: Server selection and sign-in method screens

**Files:**
- Create:
  - `ElementXWatch/Sources/Screens/ServerSelectionScreen/{ServerSelectionScreenModels,ServerSelectionScreenViewModelProtocol,ServerSelectionScreenViewModel,ServerSelectionScreenCoordinator}.swift`
  - `…/ServerSelectionScreen/View/ServerSelectionScreen.swift`
- Create:
  - `ElementXWatch/Sources/Screens/LoginMethodScreen/{LoginMethodScreenModels,LoginMethodScreenViewModelProtocol,LoginMethodScreenViewModel,LoginMethodScreenCoordinator}.swift`
  - `…/LoginMethodScreen/View/LoginMethodScreen.swift`
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/ServerSelectionScreenViewModelTests.swift`, `UnitTests/Sources/LoginMethodScreenViewModelTests.swift`

**Interfaces:**
- Consumes: `AuthenticationServiceProtocol`, `LoginOptions`, `AuthenticationError` (Task 1).
- Produces:
  ```swift
  enum ServerSelectionScreenViewModelAction { case configured(LoginOptions) }
  struct ServerSelectionScreenViewState: BindableState { var isLoading: Bool; var errorMessage: String?; var bindings: ServerSelectionScreenBindings; var canContinue: Bool }
  struct ServerSelectionScreenBindings { var server: String }   // defaults to WatchAppSettings.defaultServerName
  enum ServerSelectionScreenViewAction { case `continue` }
  final class ServerSelectionScreenCoordinator: CoordinatorProtocol { init(authenticationService: AuthenticationServiceProtocol); var actionsPublisher: AnyPublisher<ServerSelectionScreenViewModelAction, Never> }
  enum LoginMethodScreenViewModelAction { case password, qrCode }
  struct LoginMethodScreenViewState: BindableState { let options: LoginOptions }
  enum LoginMethodScreenViewAction { case password, qrCode }
  final class LoginMethodScreenCoordinator: CoordinatorProtocol { init(options: LoginOptions); var actionsPublisher: AnyPublisher<LoginMethodScreenViewModelAction, Never> }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/ServerSelectionScreenViewModelTests.swift`:

```swift
@testable import ElementXWatch
import Testing

@Suite
struct ServerSelectionScreenViewModelTests {
    @Test
    func prefillsTheDefaultServer() {
        let viewModel = ServerSelectionScreenViewModel(authenticationService: AuthenticationServiceMock())
        #expect(viewModel.context.viewState.bindings.server == "matrix.org")
        #expect(viewModel.context.viewState.canContinue)
    }

    @Test
    func emptyInputCannotContinue() {
        let viewModel = ServerSelectionScreenViewModel(authenticationService: AuthenticationServiceMock())
        viewModel.context.server = "   "
        #expect(!viewModel.context.viewState.canContinue)
    }

    @Test
    func trimsInput() async throws {
        let service = AuthenticationServiceMock()
        service.configureServerReturnValue = .success(LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: false))
        let viewModel = ServerSelectionScreenViewModel(authenticationService: service)
        viewModel.context.server = "  https://Matrix.org  "

        viewModel.context.send(viewAction: .continue)

        try await waitUntil { service.configureServerCallsCount == 1 }
        #expect(service.configureServerReceivedServer == "https://Matrix.org")
    }

    @Test
    func successReportsTheOptions() async throws {
        let options = LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: false)
        let service = AuthenticationServiceMock()
        service.configureServerReturnValue = .success(options)
        let viewModel = ServerSelectionScreenViewModel(authenticationService: service)
        var configured: LoginOptions?
        let cancellable = viewModel.actionsPublisher.sink { if case .configured(let value) = $0 { configured = value } }

        viewModel.context.send(viewAction: .continue)

        try await waitUntil { configured != nil }
        #expect(configured == options)
        #expect(!viewModel.context.viewState.isLoading)
        cancellable.cancel()
    }

    @Test
    func failuresShowAMessageAndAllowEditing() async throws {
        let service = AuthenticationServiceMock()
        service.configureServerReturnValue = .failure(.serverUnreachable)
        let viewModel = ServerSelectionScreenViewModel(authenticationService: service)

        viewModel.context.send(viewAction: .continue)

        try await waitUntil { viewModel.context.viewState.errorMessage == WatchStrings.serverUnreachable }
        #expect(!viewModel.context.viewState.isLoading)
        viewModel.context.server = "example.org"
        #expect(viewModel.context.viewState.errorMessage == nil)
    }
}
```

The last assertion needs editing the server field to clear the error. Implement that in the view model with a `didSet`-style observation of the binding: `bindings.server` is part of the state, so clear `errorMessage` inside a custom setter on the bindings struct via the view model. The simplest route is to make `errorMessage` a computed pairing, storing `failedServer: String?` in state and computing `errorMessage` only when `bindings.server == failedServer`. Use that approach.

`UnitTests/Sources/LoginMethodScreenViewModelTests.swift`:

```swift
@testable import ElementXWatch
import Testing

@Suite
struct LoginMethodScreenViewModelTests {
    @Test
    func forwardsTheChosenMethod() {
        let viewModel = LoginMethodScreenViewModel(options: LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: true))
        var actions: [LoginMethodScreenViewModelAction] = []
        let cancellable = viewModel.actionsPublisher.sink { actions.append($0) }

        viewModel.context.send(viewAction: .password)
        viewModel.context.send(viewAction: .qrCode)

        #expect(actions == [.password, .qrCode])
        cancellable.cancel()
    }

    @Test
    func unsupportedMethodsAreIgnored() {
        let viewModel = LoginMethodScreenViewModel(options: LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: false))
        var actions: [LoginMethodScreenViewModelAction] = []
        let cancellable = viewModel.actionsPublisher.sink { actions.append($0) }

        viewModel.context.send(viewAction: .qrCode)

        #expect(actions.isEmpty)
        cancellable.cancel()
    }
}
```

(Make `LoginMethodScreenViewModelAction` `Equatable`.)

- [ ] **Step 2: Run the tests to verify they fail.** They should fail to build with "cannot find … in scope".

- [ ] **Step 3: Implement**

Add to `WatchStrings`:

```swift
    static let serverTitle = "Server"
    static let serverPrompt = "Your server"
    static let continueAction = "Continue"
    static let signInMethodTitle = "Sign in"
    static let signInWithPassword = "Sign in with password"
    static let signInWithIPhone = "Sign in with iPhone"
    static let noSignInMethods = "This server doesn't support signing in from a watch."
```

`ServerSelectionScreenModels.swift`:

```swift
enum ServerSelectionScreenViewModelAction {
    case configured(LoginOptions)
}

struct ServerSelectionScreenViewState: BindableState {
    var isLoading = false
    /// The input that failed, so editing the field hides the error.
    var failedServer: String?
    var failureMessage: String?
    var bindings = ServerSelectionScreenBindings()

    var trimmedServer: String {
        bindings.server.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canContinue: Bool {
        !isLoading && !trimmedServer.isEmpty
    }

    var errorMessage: String? {
        failedServer == bindings.server ? failureMessage : nil
    }
}

struct ServerSelectionScreenBindings {
    var server = WatchAppSettings.defaultServerName
}

enum ServerSelectionScreenViewAction {
    case `continue`
}
```

`ServerSelectionScreenViewModel.swift`:

```swift
import Combine

typealias ServerSelectionScreenViewModelType = StateStoreViewModelV2<ServerSelectionScreenViewState, ServerSelectionScreenViewAction>

final class ServerSelectionScreenViewModel: ServerSelectionScreenViewModelType, ServerSelectionScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let actionsSubject = PassthroughSubject<ServerSelectionScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<ServerSelectionScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: AuthenticationServiceProtocol) {
        self.authenticationService = authenticationService
        super.init(initialViewState: ServerSelectionScreenViewState())
    }

    override func process(viewAction: ServerSelectionScreenViewAction) {
        switch viewAction {
        case .continue:
            configure()
        }
    }

    private func configure() {
        guard state.canContinue else { return }
        let input = state.bindings.server
        state.isLoading = true

        Task {
            let result = await authenticationService.configure(server: state.trimmedServer)
            state.isLoading = false
            switch result {
            case .success(let options):
                actionsSubject.send(.configured(options))
            case .failure(let error):
                state.failedServer = input
                state.failureMessage = error.message
            }
        }
    }
}
```

`ServerSelectionScreenViewModelProtocol.swift`, `ServerSelectionScreenCoordinator.swift`: the same shape as `ChatsScreenViewModelProtocol` / `ChatsScreenCoordinator` (an `actionsPublisher` plus `context`; the coordinator owns the view model and `toPresentable()` returns `AnyView(ServerSelectionScreen(context: viewModel.context))`).

`View/ServerSelectionScreen.swift`:

```swift
import SwiftUI

struct ServerSelectionScreen: View {
    @Bindable var context: ServerSelectionScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TextField(WatchStrings.serverPrompt, text: $context.server)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(context.viewState.isLoading)
                if let error = context.viewState.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Color.compound.textCriticalPrimary)
                }
                if context.viewState.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Button(WatchStrings.continueAction) { context.send(viewAction: .continue) }
                        .disabled(!context.viewState.canContinue)
                        .tint(Color.compound.bgAccentRest)
                }
            }
        }
        .navigationTitle(WatchStrings.serverTitle)
    }
}

// MARK: - Previews

struct ServerSelectionScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { ServerSelectionScreen(context: makeViewModel().context) }
            .previewDisplayName("Default")
        NavigationStack { ServerSelectionScreen(context: makeViewModel(isLoading: true).context) }
            .previewDisplayName("Loading")
        NavigationStack { ServerSelectionScreen(context: makeViewModel(error: WatchStrings.serverUnreachable).context) }
            .previewDisplayName("Error")
    }

    static func makeViewModel(isLoading: Bool = false, error: String? = nil) -> ServerSelectionScreenViewModel {
        let viewModel = ServerSelectionScreenViewModel(authenticationService: AuthenticationServiceMock())
        viewModel.state.isLoading = isLoading
        if let error {
            viewModel.state.failedServer = viewModel.state.bindings.server
            viewModel.state.failureMessage = error
        }
        return viewModel
    }
}
```

`LoginMethodScreenModels.swift`:

```swift
enum LoginMethodScreenViewModelAction: Equatable {
    case password
    case qrCode
}

struct LoginMethodScreenViewState: BindableState {
    let options: LoginOptions
}

enum LoginMethodScreenViewAction {
    case password
    case qrCode
}
```

`LoginMethodScreenViewModel.swift`:

```swift
import Combine

typealias LoginMethodScreenViewModelType = StateStoreViewModelV2<LoginMethodScreenViewState, LoginMethodScreenViewAction>

final class LoginMethodScreenViewModel: LoginMethodScreenViewModelType, LoginMethodScreenViewModelProtocol {
    private let actionsSubject = PassthroughSubject<LoginMethodScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<LoginMethodScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(options: LoginOptions) {
        super.init(initialViewState: LoginMethodScreenViewState(options: options))
    }

    override func process(viewAction: LoginMethodScreenViewAction) {
        switch viewAction {
        case .password where state.options.supportsPassword:
            actionsSubject.send(.password)
        case .qrCode where state.options.supportsQRCode:
            actionsSubject.send(.qrCode)
        default:
            break
        }
    }
}
```

The protocol and coordinator follow the same pattern (the coordinator's `init(options:)`).

`View/LoginMethodScreen.swift`:

```swift
import SwiftUI

struct LoginMethodScreen: View {
    let context: LoginMethodScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(context.viewState.options.serverName)
                    .font(.footnote)
                    .foregroundStyle(Color.compound.textSecondary)
                if context.viewState.options.supportsPassword {
                    Button(WatchStrings.signInWithPassword) { context.send(viewAction: .password) }
                        .tint(Color.compound.bgAccentRest)
                }
                if context.viewState.options.supportsQRCode {
                    Button(WatchStrings.signInWithIPhone) { context.send(viewAction: .qrCode) }
                }
                if !context.viewState.options.supportsAnyMethod {
                    Text(WatchStrings.noSignInMethods).multilineTextAlignment(.center)
                }
            }
        }
        .navigationTitle(WatchStrings.signInMethodTitle)
    }
}

// MARK: - Previews

struct LoginMethodScreen_Previews: PreviewProvider {
    static var previews: some View {
        preview(password: true, qr: false, name: "Password only")
        preview(password: true, qr: true, name: "Both")
        preview(password: false, qr: false, name: "Unsupported")
    }

    static func preview(password: Bool, qr: Bool, name: String) -> some View {
        NavigationStack {
            LoginMethodScreen(context: LoginMethodScreenViewModel(options: LoginOptions(serverName: "matrix.org",
                                                                                        supportsPassword: password,
                                                                                        supportsQRCode: qr)).context)
        }
        .previewDisplayName(name)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass.** Run the standard command: the new suites (5 + 2) plus everything else pass, with no warnings.

- [ ] **Step 5: Commit**: "Add server selection and sign-in method screens", with a description and the trailers.

---

### Task 3: Password sign-in screen

**Files:**
- Create:
  - `ElementXWatch/Sources/Screens/PasswordLoginScreen/{PasswordLoginScreenModels,PasswordLoginScreenViewModelProtocol,PasswordLoginScreenViewModel,PasswordLoginScreenCoordinator}.swift`
  - `…/PasswordLoginScreen/View/PasswordLoginScreen.swift`
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/PasswordLoginScreenViewModelTests.swift`

**Interfaces:**
- Consumes: `AuthenticationServiceProtocol.login(username:password:)`, `AuthenticationError` (Task 1).
- Produces:
  ```swift
  enum PasswordLoginScreenViewModelAction { case signedIn(ClientProxyProtocol) }
  struct PasswordLoginScreenViewState: BindableState { let serverName: String; var isLoading: Bool; var errorMessage: String?; var bindings: PasswordLoginScreenBindings; var canSignIn: Bool }
  struct PasswordLoginScreenBindings { var username: String; var password: String }
  enum PasswordLoginScreenViewAction { case signIn }
  final class PasswordLoginScreenCoordinator: CoordinatorProtocol { init(serverName: String, authenticationService: AuthenticationServiceProtocol); var actionsPublisher: AnyPublisher<PasswordLoginScreenViewModelAction, Never> }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/PasswordLoginScreenViewModelTests.swift`:

```swift
@testable import ElementXWatch
import Testing

@Suite
struct PasswordLoginScreenViewModelTests {
    @Test
    func signInNeedsBothFields() {
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: AuthenticationServiceMock())
        #expect(!viewModel.context.viewState.canSignIn)
        viewModel.context.username = "alice"
        #expect(!viewModel.context.viewState.canSignIn)
        viewModel.context.password = "secret"
        #expect(viewModel.context.viewState.canSignIn)
    }

    @Test
    func successEmitsSignedIn() async throws {
        let service = AuthenticationServiceMock()
        let clientProxy = ClientProxyMock()
        service.loginUsernamePasswordReturnValue = .success(clientProxy)
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: service)
        var signedIn: ClientProxyProtocol?
        let cancellable = viewModel.actionsPublisher.sink { if case .signedIn(let proxy) = $0 { signedIn = proxy } }
        viewModel.context.username = " alice "
        viewModel.context.password = "secret"

        viewModel.context.send(viewAction: .signIn)

        try await waitUntil { signedIn != nil }
        #expect(signedIn === clientProxy)
        #expect(service.loginUsernamePasswordReceivedArguments?.username == "alice")
        cancellable.cancel()
    }

    @Test
    func wrongPasswordKeepsUsernameAndClearsPassword() async throws {
        let service = AuthenticationServiceMock()
        service.loginUsernamePasswordReturnValue = .failure(.invalidCredentials)
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: service)
        viewModel.context.username = "alice"
        viewModel.context.password = "wrong"

        viewModel.context.send(viewAction: .signIn)

        try await waitUntil { viewModel.context.viewState.errorMessage == WatchStrings.wrongCredentials }
        #expect(viewModel.context.viewState.bindings.username == "alice")
        #expect(viewModel.context.viewState.bindings.password.isEmpty)
        #expect(!viewModel.context.viewState.isLoading)
    }

    @Test
    func rateLimitingIsExplained() async throws {
        let service = AuthenticationServiceMock()
        service.loginUsernamePasswordReturnValue = .failure(.rateLimited)
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: service)
        viewModel.context.username = "alice"
        viewModel.context.password = "secret"

        viewModel.context.send(viewAction: .signIn)

        try await waitUntil { viewModel.context.viewState.errorMessage == WatchStrings.rateLimited }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail.** They should fail to build.

- [ ] **Step 3: Implement**

Add to `WatchStrings`:

```swift
    static let usernamePrompt = "Username"
    static let passwordPrompt = "Password"
    static let signInAction = "Sign in"
```

`PasswordLoginScreenModels.swift`:

```swift
enum PasswordLoginScreenViewModelAction {
    case signedIn(ClientProxyProtocol)
}

struct PasswordLoginScreenViewState: BindableState {
    let serverName: String
    var isLoading = false
    var errorMessage: String?
    var bindings = PasswordLoginScreenBindings()

    var canSignIn: Bool {
        !isLoading && !bindings.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !bindings.password.isEmpty
    }
}

struct PasswordLoginScreenBindings {
    var username = ""
    var password = ""
}

enum PasswordLoginScreenViewAction {
    case signIn
}
```

`PasswordLoginScreenViewModel.swift`:

```swift
import Combine

typealias PasswordLoginScreenViewModelType = StateStoreViewModelV2<PasswordLoginScreenViewState, PasswordLoginScreenViewAction>

final class PasswordLoginScreenViewModel: PasswordLoginScreenViewModelType, PasswordLoginScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let actionsSubject = PassthroughSubject<PasswordLoginScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<PasswordLoginScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(serverName: String, authenticationService: AuthenticationServiceProtocol) {
        self.authenticationService = authenticationService
        super.init(initialViewState: PasswordLoginScreenViewState(serverName: serverName))
    }

    override func process(viewAction: PasswordLoginScreenViewAction) {
        switch viewAction {
        case .signIn:
            signIn()
        }
    }

    private func signIn() {
        guard state.canSignIn else { return }
        let username = state.bindings.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = state.bindings.password
        state.isLoading = true
        state.errorMessage = nil

        Task {
            let result = await authenticationService.login(username: username, password: password)
            state.isLoading = false
            switch result {
            case .success(let clientProxy):
                actionsSubject.send(.signedIn(clientProxy))
            case .failure(let error):
                state.bindings.password = ""
                state.errorMessage = error.message
            }
        }
    }
}
```

The protocol and coordinator follow the pattern (the coordinator's `init(serverName:authenticationService:)`).

`View/PasswordLoginScreen.swift`:

```swift
import SwiftUI

struct PasswordLoginScreen: View {
    @Bindable var context: PasswordLoginScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(context.viewState.serverName).font(.footnote).foregroundStyle(Color.compound.textSecondary)
                TextField(WatchStrings.usernamePrompt, text: $context.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField(WatchStrings.passwordPrompt, text: $context.password)
                    .textContentType(.password)
                if let error = context.viewState.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Color.compound.textCriticalPrimary)
                }
                if context.viewState.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Button(WatchStrings.signInAction) { context.send(viewAction: .signIn) }
                        .disabled(!context.viewState.canSignIn)
                        .tint(Color.compound.bgAccentRest)
                }
            }
            .disabled(context.viewState.isLoading)
        }
        .navigationTitle(WatchStrings.signInMethodTitle)
    }
}

// MARK: - Previews

struct PasswordLoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { PasswordLoginScreen(context: makeViewModel().context) }.previewDisplayName("Empty")
        NavigationStack { PasswordLoginScreen(context: makeViewModel(isLoading: true).context) }.previewDisplayName("Signing in")
        NavigationStack { PasswordLoginScreen(context: makeViewModel(error: WatchStrings.wrongCredentials).context) }.previewDisplayName("Error")
    }

    static func makeViewModel(isLoading: Bool = false, error: String? = nil) -> PasswordLoginScreenViewModel {
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: AuthenticationServiceMock())
        viewModel.state.bindings.username = "alice"
        viewModel.state.isLoading = isLoading
        viewModel.state.errorMessage = error
        return viewModel
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass.** Run the standard command: 4 new tests plus the rest pass, with no warnings.

- [ ] **Step 5: Commit**: "Add the password sign-in screen", with a description and the trailers.

---

### Task 4: Authentication flow routing and app wiring

**Files:**
- Modify: `ElementXWatch/Sources/FlowCoordinators/AuthenticationFlowCoordinator.swift` (rewrite)
- Modify: `ElementXWatch/Sources/Application/AppCoordinator.swift`, `ElementXWatch/Sources/Application/ElementXWatchApp.swift`
- Modify: `UnitTests/Sources/AppCoordinatorTests.swift` (constructor change)
- Test: `UnitTests/Sources/AuthenticationFlowCoordinatorTests.swift`

**Interfaces:**
- Consumes:
  - Task 1's `AuthenticationServiceProtocol`, `LoginOptions`;
  - Task 2's `ServerSelectionScreenCoordinator` and `LoginMethodScreenCoordinator`;
  - Task 3's `PasswordLoginScreenCoordinator`;
  - the existing `QRLoginScreenCoordinator(qrLoginService:)` (`actionsPublisher` → `.signedIn(ClientProxyProtocol)`).
- Produces:
  ```swift
  enum AuthenticationRoute: Hashable { case method(LoginOptions), password(serverName: String), qrCode }
  struct SignedIn { let clientProxy: ClientProxyProtocol; let needsVerification: Bool }
  final class AuthenticationFlowCoordinator: CoordinatorProtocol {
      init(authenticationService: AuthenticationServiceProtocol, qrLoginService: QRLoginServiceProtocol)
      var signedInPublisher: AnyPublisher<SignedIn, Never>
      var path: [AuthenticationRoute] { get }              // for tests
      func handlePathChange(_ path: [AuthenticationRoute])   // resets the pending login when the user backs out to the server screen
  }
  // AppCoordinator:
  init(sessionStore: SessionStoreProtocol, restorer: UserSessionRestorerProtocol, authenticationService: AuthenticationServiceProtocol, qrLoginService: QRLoginServiceProtocol)
  // showSession(_:needsVerification:) passes needsVerification to UserSessionFlowCoordinator (Task 7 consumes it).
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/AuthenticationFlowCoordinatorTests.swift`:

```swift
import Combine
@testable import ElementXWatch
import Testing

@Suite
struct AuthenticationFlowCoordinatorTests {
    @Test
    func configuredServerPushesTheMethodScreen() async throws {
        let (coordinator, service, _) = makeCoordinator()
        let options = LoginOptions(serverName: "matrix.org", supportsPassword: true, supportsQRCode: false)
        service.configureServerReturnValue = .success(options)

        coordinator.serverScreen.context.send(viewAction: .continue)

        try await waitUntil { coordinator.path == [.method(options)] }
    }

    @Test
    func passwordSignInIsReportedAsNeedingVerification() async throws {
        let (coordinator, service, _) = makeCoordinator()
        let proxy = ClientProxyMock()
        service.loginUsernamePasswordReturnValue = .success(proxy)
        var signedIn: SignedIn?
        let cancellable = coordinator.signedInPublisher.sink { signedIn = $0 }

        coordinator.showPassword(serverName: "matrix.org")
        let password = try #require(coordinator.passwordScreen)
        password.context.username = "alice"
        password.context.password = "secret"
        password.context.send(viewAction: .signIn)

        try await waitUntil { signedIn != nil }
        #expect(signedIn?.clientProxy === proxy)
        #expect(signedIn?.needsVerification == true)
        cancellable.cancel()
    }

    @Test
    func qrSignInDoesNotNeedVerification() async throws {
        let (coordinator, _, qrService) = makeCoordinator()
        let proxy = ClientProxyMock()
        qrService.loginWithGeneratedQRCodeOnProgressClosure = { _ in .success(proxy) }
        var signedIn: SignedIn?
        let cancellable = coordinator.signedInPublisher.sink { signedIn = $0 }

        coordinator.showQRCode()
        try #require(coordinator.qrScreen).context.send(viewAction: .start)

        try await waitUntil { signedIn != nil }
        #expect(signedIn?.needsVerification == false)
        cancellable.cancel()
    }

    @Test
    func backToServerResetsPendingLogin() {
        let (coordinator, service, _) = makeCoordinator()
        coordinator.handlePathChange([.method(LoginOptions(serverName: "a", supportsPassword: true, supportsQRCode: false))])

        coordinator.handlePathChange([])

        #expect(service.resetCallsCount == 1)
    }

    // MARK: - Helpers

    private func makeCoordinator() -> (AuthenticationFlowCoordinator, AuthenticationServiceMock, QRLoginServiceMock) {
        let service = AuthenticationServiceMock()
        let qrService = QRLoginServiceMock()
        let coordinator = AuthenticationFlowCoordinator(authenticationService: service, qrLoginService: qrService)
        coordinator.start()
        return (coordinator, service, qrService)
    }
}
```

These tests drive the coordinator through small internal hooks: `serverScreen`, `passwordScreen`, `qrScreen` (the current child view models' contexts), plus `showPassword(serverName:)` and `showQRCode()`, which are the same functions the method-screen actions call. Expose them as `internal`, and document them as test hooks where they aren't otherwise needed.

- [ ] **Step 2: Run the tests to verify they fail.** They should fail to build.

- [ ] **Step 3: Implement**

`AuthenticationFlowCoordinator.swift` (rewrite; keep the watch header):

```swift
import Combine
import Observation
import SwiftUI

enum AuthenticationRoute: Hashable {
    case method(LoginOptions)
    case password(serverName: String)
    case qrCode
}

struct SignedIn {
    let clientProxy: ClientProxyProtocol
    /// Password sign-ins start unverified; QR sign-ins arrive verified.
    let needsVerification: Bool
}

/// The signed-out flow: server → sign-in method → password or QR code.
final class AuthenticationFlowCoordinator: CoordinatorProtocol {
    @Observable final class Navigation {
        var path: [AuthenticationRoute] = []
    }

    private let authenticationService: AuthenticationServiceProtocol
    private let qrLoginService: QRLoginServiceProtocol
    private let serverCoordinator: ServerSelectionScreenCoordinator
    private let navigation = Navigation()
    private let signedInSubject = PassthroughSubject<SignedIn, Never>()
    private var methodCoordinator: LoginMethodScreenCoordinator?
    private var passwordCoordinator: PasswordLoginScreenCoordinator?
    private var qrCoordinator: QRLoginScreenCoordinator?
    private var cancellables = Set<AnyCancellable>()

    var signedInPublisher: AnyPublisher<SignedIn, Never> { signedInSubject.eraseToAnyPublisher() }
    var path: [AuthenticationRoute] { navigation.path }
    // Test hooks: the current screens' contexts.
    var serverScreen: ServerSelectionScreenViewModel.Context { serverCoordinator.context }
    var passwordScreen: PasswordLoginScreenViewModel.Context? { passwordCoordinator?.context }
    var qrScreen: QRLoginScreenViewModel.Context? { qrCoordinator?.context }

    init(authenticationService: AuthenticationServiceProtocol, qrLoginService: QRLoginServiceProtocol) {
        self.authenticationService = authenticationService
        self.qrLoginService = qrLoginService
        serverCoordinator = ServerSelectionScreenCoordinator(authenticationService: authenticationService)
    }

    func start() {
        serverCoordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .configured(let options): self?.showMethods(options)
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        AnyView(AuthenticationFlowView(navigation: navigation,
                                       root: serverCoordinator.toPresentable(),
                                       destination: { [weak self] route in self?.destination(for: route) ?? AnyView(EmptyView()) },
                                       onPathChange: { [weak self] path in self?.handlePathChange(path) }))
    }

    func handlePathChange(_ path: [AuthenticationRoute]) {
        if path.isEmpty {
            // Back on the server screen: the configured login client is no longer wanted.
            methodCoordinator = nil
            passwordCoordinator = nil
            qrCoordinator = nil
            authenticationService.reset()
        } else if !path.contains(where: { if case .password = $0 { true } else { false } }) {
            passwordCoordinator = nil
        } else if !path.contains(.qrCode) {
            qrCoordinator = nil
        }
    }

    func showPassword(serverName: String) {
        let coordinator = PasswordLoginScreenCoordinator(serverName: serverName, authenticationService: authenticationService)
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let clientProxy): self?.signedInSubject.send(SignedIn(clientProxy: clientProxy, needsVerification: true))
                }
            }
            .store(in: &cancellables)
        passwordCoordinator = coordinator
        navigation.path.append(.password(serverName: serverName))
    }

    func showQRCode() {
        let coordinator = QRLoginScreenCoordinator(qrLoginService: qrLoginService)
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let clientProxy): self?.signedInSubject.send(SignedIn(clientProxy: clientProxy, needsVerification: false))
                }
            }
            .store(in: &cancellables)
        qrCoordinator = coordinator
        navigation.path.append(.qrCode)
    }

    private func showMethods(_ options: LoginOptions) {
        let coordinator = LoginMethodScreenCoordinator(options: options)
        coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .password: self?.showPassword(serverName: options.serverName)
                case .qrCode: self?.showQRCode()
                }
            }
            .store(in: &cancellables)
        methodCoordinator = coordinator
        navigation.path = [.method(options)]
    }

    private func destination(for route: AuthenticationRoute) -> AnyView {
        switch route {
        case .method: methodCoordinator?.toPresentable() ?? AnyView(EmptyView())
        case .password: passwordCoordinator?.toPresentable() ?? AnyView(EmptyView())
        case .qrCode: qrCoordinator?.toPresentable() ?? AnyView(EmptyView())
        }
    }
}

private struct AuthenticationFlowView: View {
    @Bindable var navigation: AuthenticationFlowCoordinator.Navigation
    let root: AnyView
    let destination: (AuthenticationRoute) -> AnyView
    let onPathChange: ([AuthenticationRoute]) -> Void

    var body: some View {
        NavigationStack(path: $navigation.path) {
            root.navigationDestination(for: AuthenticationRoute.self) { route in destination(route) }
        }
        .onChange(of: navigation.path) { _, path in onPathChange(path) }
    }
}
```

Give each screen coordinator (Server, Password, QRLogin) an internal `var context: …ViewModel.Context { viewModel.context }` so the flow's test hooks can reach it. `QRLoginScreenCoordinator` needs that one-line addition.

`handlePathChange` only drops the coordinators for routes that are no longer on the stack. Keep the conditions simple and correct: for each of password and QR, drop its coordinator when its route is absent.

`AppCoordinator.swift`:
- Replace the `qrLoginService`-only init with `init(sessionStore:restorer:authenticationService:qrLoginService:)`, storing both.
- `showAuthentication()` creates `AuthenticationFlowCoordinator(authenticationService:qrLoginService:)` and subscribes: `.sink { [weak self] signedIn in self?.showSession(signedIn.clientProxy, needsVerification: signedIn.needsVerification) }`.
- Change `showSession(_:)` to `showSession(_ clientProxy: ClientProxyProtocol, needsVerification: Bool = false)`, and have it pass `needsVerification` to `UserSessionFlowCoordinator(clientProxy:showsVerificationOnStart:)`. For now add that parameter with a default of `false` in `UserSessionFlowCoordinator` and store it unused; Task 7 implements it.
- The restore path calls `showSession(clientProxy)`, which is not verification.

`ElementXWatchApp.swift`: `AppCoordinator(sessionStore:, restorer:, authenticationService: authenticationService, qrLoginService: authenticationService)`.

`AppCoordinatorTests.swift`: update `makeCoordinator()` to pass `authenticationService: AuthenticationServiceMock()` and `qrLoginService: QRLoginServiceMock()`. All existing tests keep their assertions.

- [ ] **Step 4: Run the tests to verify they pass.** Run the standard command (full suite): `AuthenticationFlowCoordinatorTests` (4) plus all existing tests pass, with no warnings.

- [ ] **Step 5: Smoke run.** Build, install and launch in the watchOS 26.5 simulator (as in the sub-project 1 Task 18 smoke run) and screenshot the launch. It should show the **Server** screen with `matrix.org` and Continue.

- [ ] **Step 6: Commit**: "Route sign-in through server choice and method selection", with a description and the trailers.

---

### Task 5: `SessionVerificationControllerProxy`

**Files:**
- Create: `ElementXWatch/Sources/Services/SessionVerification/SessionVerificationControllerProxyProtocol.swift` and `SessionVerificationControllerProxy.swift`. Derive both from element-x-ios `ElementX/Sources/Services/SessionVerification/`, keeping their copyright headers and adding `SHARED_FROM_IOS.md` rows.
- Modify: `ElementXWatch/Sources/Services/Client/ClientProxyProtocol.swift`, `ClientProxy.swift` (add `sessionVerificationController()`), `ElementXWatch/Sources/Mocks/ClientProxyMock+Preview.swift` (set a nil return value)
- Test: `UnitTests/Sources/SessionVerificationMappingTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct VerificationEmoji: Hashable, Identifiable { let symbol: String; let description: String; var id: String }
  enum VerificationData: Equatable { case emojis([VerificationEmoji]); case decimals([UInt16]) }
  enum SessionVerificationControllerProxyAction: Equatable { case acceptedVerificationRequest, startedSasVerification, receivedVerificationData(VerificationData), finished, cancelled, failed }
  enum SessionVerificationControllerProxyError: Error { case failedRequestingVerification, failedStartingSasVerification, failedApprovingVerification, failedDecliningVerification, failedCancellingVerification }
  // sourcery: AutoMockable
  protocol SessionVerificationControllerProxyProtocol: AnyObject {
      var actionsPublisher: AnyPublisher<SessionVerificationControllerProxyAction, Never> { get }
      func requestDeviceVerification() async -> Result<Void, SessionVerificationControllerProxyError>
      func startSasVerification() async -> Result<Void, SessionVerificationControllerProxyError>
      func approveVerification() async -> Result<Void, SessionVerificationControllerProxyError>
      func declineVerification() async -> Result<Void, SessionVerificationControllerProxyError>
      func cancelVerification() async -> Result<Void, SessionVerificationControllerProxyError>
  }
  final class SessionVerificationControllerProxy: SessionVerificationControllerProxyProtocol { init(controller: SessionVerificationController) }
  // ClientProxyProtocol gains:
  func sessionVerificationController() async -> SessionVerificationControllerProxyProtocol?
  ```

- [ ] **Step 1: Write the failing test**

`UnitTests/Sources/SessionVerificationMappingTests.swift`:

```swift
@testable import ElementXWatch
import Testing

struct SessionVerificationMappingTests {
    @Test
    func decimalsMapThrough() {
        #expect(VerificationData(rustData: .decimals(values: [1, 2, 3])) == .decimals([1, 2, 3]))
    }

    @Test
    func emojiIdentityIsSymbolAndDescription() {
        let emoji = VerificationEmoji(symbol: "🐶", description: "Dog")
        #expect(emoji.id == "🐶Dog")
    }
}
```

The emoji case needs SDK `SessionVerificationEmoji` objects, which can't be constructed, so only the decimals case is mapped in the test.

- [ ] **Step 2: Run the tests to verify they fail.** They should fail to build.

- [ ] **Step 3: Implement**

`SessionVerificationControllerProxyProtocol.swift` (keeping the iOS header):

```swift
import Combine
import Foundation
import MatrixRustSDK

struct VerificationEmoji: Hashable, Identifiable {
    let symbol: String
    let description: String

    var id: String {
        symbol + description
    }
}

enum VerificationData: Equatable {
    case emojis([VerificationEmoji])
    case decimals([UInt16])

    init(rustData: SessionVerificationData) {
        switch rustData {
        case .emojis(let emojis, _):
            self = .emojis(emojis.map { VerificationEmoji(symbol: $0.symbol(), description: $0.description()) })
        case .decimals(let values):
            self = .decimals(values)
        }
    }
}

enum SessionVerificationControllerProxyAction: Equatable {
    case acceptedVerificationRequest
    case startedSasVerification
    case receivedVerificationData(VerificationData)
    case finished
    case cancelled
    case failed
}

enum SessionVerificationControllerProxyError: Error {
    case failedRequestingVerification
    case failedStartingSasVerification
    case failedApprovingVerification
    case failedDecliningVerification
    case failedCancellingVerification
}

// sourcery: AutoMockable
protocol SessionVerificationControllerProxyProtocol: AnyObject {
    var actionsPublisher: AnyPublisher<SessionVerificationControllerProxyAction, Never> { get }

    /// Asks this account's other devices to verify this one.
    func requestDeviceVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    func startSasVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    func approveVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    func declineVerification() async -> Result<Void, SessionVerificationControllerProxyError>
    func cancelVerification() async -> Result<Void, SessionVerificationControllerProxyError>
}
```

`SessionVerificationControllerProxy.swift` (keeping the iOS header):

```swift
import Combine
import MatrixRustSDK

final class SessionVerificationControllerProxy: SessionVerificationControllerProxyProtocol {
    private let controller: SessionVerificationController
    private let actionsSubject = PassthroughSubject<SessionVerificationControllerProxyAction, Never>()

    var actionsPublisher: AnyPublisher<SessionVerificationControllerProxyAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(controller: SessionVerificationController) {
        self.controller = controller
        controller.setDelegate(delegate: SessionVerificationDelegateForwarder { [weak self] action in
            MXLog.info("Session verification: \(action)")
            self?.actionsSubject.send(action)
        })
    }

    deinit {
        controller.setDelegate(delegate: nil)
    }

    func requestDeviceVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedRequestingVerification) { try await self.controller.requestDeviceVerification() }
    }

    func startSasVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedStartingSasVerification) { try await self.controller.startSasVerification() }
    }

    func approveVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedApprovingVerification) { try await self.controller.approveVerification() }
    }

    func declineVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedDecliningVerification) { try await self.controller.declineVerification() }
    }

    func cancelVerification() async -> Result<Void, SessionVerificationControllerProxyError> {
        await run(.failedCancellingVerification) { try await self.controller.cancelVerification() }
    }

    private func run(_ failure: SessionVerificationControllerProxyError, _ operation: () async throws -> Void) async -> Result<Void, SessionVerificationControllerProxyError> {
        do {
            try await operation()
            return .success(())
        } catch {
            MXLog.error("Session verification step failed (\(failure)): \(type(of: error))")
            return .failure(failure)
        }
    }
}

/// Forwards the SDK's delegate callbacks (background threads) onto the main actor.
private nonisolated final class SessionVerificationDelegateForwarder: SessionVerificationControllerDelegate {
    private let forward: @Sendable (SessionVerificationControllerProxyAction) -> Void

    init(onAction: @escaping @MainActor (SessionVerificationControllerProxyAction) -> Void) {
        let listener = SDKListener<SessionVerificationControllerProxyAction>.onMainActor(onAction)
        forward = { listener.forward($0) }
    }

    func didReceiveVerificationRequest(details: SessionVerificationRequestDetails) {
        // Requests started by other devices are out of scope (spec §3).
    }

    func didAcceptVerificationRequest() { forward(.acceptedVerificationRequest) }
    func didStartSasVerification() { forward(.startedSasVerification) }
    func didReceiveVerificationData(data: SessionVerificationData) { forward(.receivedVerificationData(VerificationData(rustData: data))) }
    func didFail() { forward(.failed) }
    func didCancel() { forward(.cancelled) }
    func didFinish() { forward(.finished) }
}
```

Its log line prints `SessionVerificationControllerProxyAction`, whose `receivedVerificationData` case carries emojis. Give `SessionVerificationControllerProxyAction` a case-name-only `CustomStringConvertible` so emoji values are never logged.

If `SessionVerificationControllerProxyAction` must be `Sendable` for `SDKListener<T>.onMainActor`, make `VerificationEmoji`, `VerificationData` and the action `Sendable`. They're value types, so this is automatic, but declare it explicitly.

In `ClientProxyProtocol`, add `func sessionVerificationController() async -> SessionVerificationControllerProxyProtocol?`. In `ClientProxy`:

```swift
    func sessionVerificationController() async -> SessionVerificationControllerProxyProtocol? {
        do {
            return try await SessionVerificationControllerProxy(controller: client.getSessionVerificationController())
        } catch {
            MXLog.error("Failed to get the session verification controller: \(error)")
            return nil
        }
    }
```

In `ClientProxyMock+Preview.swift`, set `mock.sessionVerificationControllerReturnValue = nil` (the Sourcery name for this method).

- [ ] **Step 4: Run the tests to verify they pass.** Run the standard command (full suite), with no warnings.

- [ ] **Step 5: Commit**: add the two `SHARED_FROM_IOS.md` rows (for the `SessionVerification…` files: "Own-device SAS only; delegate forwarded on the main actor; emojis mapped to value types; incoming requests ignored"). Commit message: "Wrap the SDK's session verification controller", with a description and the trailers.

---

### Task 6: Session verification screen

**Files:**
- Create:
  - `ElementXWatch/Sources/Screens/SessionVerificationScreen/{SessionVerificationScreenModels,SessionVerificationScreenViewModelProtocol,SessionVerificationScreenViewModel,SessionVerificationScreenCoordinator}.swift`
  - `…/SessionVerificationScreen/View/SessionVerificationScreen.swift`
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/SessionVerificationScreenViewModelTests.swift`

**Interfaces:**
- Consumes: `SessionVerificationControllerProxyProtocol`, `SessionVerificationControllerProxyAction`, `VerificationData` (Task 5).
- Produces:
  ```swift
  enum SessionVerificationStep: Equatable { case intro, waitingForAcceptance, startingSas, comparing(VerificationData), confirming, verified, declined, cancelled, failed }
  struct SessionVerificationScreenViewState: BindableState { var step: SessionVerificationStep }
  enum SessionVerificationScreenViewAction { case start, match, noMatch, cancel, tryAgain, dismiss }
  enum SessionVerificationScreenViewModelAction { case dismiss }
  final class SessionVerificationScreenViewModel { init(controllerProxy: SessionVerificationControllerProxyProtocol?) }
  final class SessionVerificationScreenCoordinator: CoordinatorProtocol { init(controllerProxy: SessionVerificationControllerProxyProtocol?); var actionsPublisher: AnyPublisher<SessionVerificationScreenViewModelAction, Never> }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/SessionVerificationScreenViewModelTests.swift`:

```swift
import Combine
@testable import ElementXWatch
import Testing

@Suite
struct SessionVerificationScreenViewModelTests {
    @Test
    func fullHappyPath() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        let emojis = [VerificationEmoji(symbol: "🐶", description: "Dog")]

        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .waitingForAcceptance }
        #expect(proxy.requestDeviceVerificationCallsCount == 1)

        actions.send(.acceptedVerificationRequest)
        try await waitUntil { proxy.startSasVerificationCallsCount == 1 }

        actions.send(.receivedVerificationData(.emojis(emojis)))
        try await waitUntil { viewModel.context.viewState.step == .comparing(.emojis(emojis)) }

        viewModel.context.send(viewAction: .match)
        try await waitUntil { proxy.approveVerificationCallsCount == 1 }
        #expect(viewModel.context.viewState.step == .confirming)

        actions.send(.finished)
        try await waitUntil { viewModel.context.viewState.step == .verified }
    }

    @Test
    func noMatchDeclines() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        actions.send(.acceptedVerificationRequest)
        actions.send(.receivedVerificationData(.decimals([1, 2, 3])))
        try await waitUntil { viewModel.context.viewState.step == .comparing(.decimals([1, 2, 3])) }

        viewModel.context.send(viewAction: .noMatch)

        try await waitUntil { viewModel.context.viewState.step == .declined }
        #expect(proxy.declineVerificationCallsCount == 1)
    }

    @Test
    func cancelledOrFailedOffersTryAgain() async throws {
        let (viewModel, proxy, actions) = makeViewModel()
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .waitingForAcceptance }

        actions.send(.cancelled)
        try await waitUntil { viewModel.context.viewState.step == .cancelled }

        viewModel.context.send(viewAction: .tryAgain)
        try await waitUntil { proxy.requestDeviceVerificationCallsCount == 2 }

        actions.send(.failed)
        try await waitUntil { viewModel.context.viewState.step == .failed }
    }

    @Test
    func requestFailureShowsFailed() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.requestDeviceVerificationReturnValue = .failure(.failedRequestingVerification)

        viewModel.context.send(viewAction: .start)

        try await waitUntil { viewModel.context.viewState.step == .failed }
    }

    @Test
    func missingControllerShowsFailed() async throws {
        let viewModel = SessionVerificationScreenViewModel(controllerProxy: nil)
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .failed }
    }

    @Test
    func cancelWhileWaitingCancelsAndDismissIsForwarded() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        var dismissed = false
        let cancellable = viewModel.actionsPublisher.sink { if case .dismiss = $0 { dismissed = true } }
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .waitingForAcceptance }

        viewModel.context.send(viewAction: .cancel)
        try await waitUntil { proxy.cancelVerificationCallsCount == 1 }
        viewModel.context.send(viewAction: .dismiss)

        #expect(dismissed)
        cancellable.cancel()
    }

    // MARK: - Helpers

    private func makeViewModel() -> (SessionVerificationScreenViewModel, SessionVerificationControllerProxyMock, PassthroughSubject<SessionVerificationControllerProxyAction, Never>) {
        let actions = PassthroughSubject<SessionVerificationControllerProxyAction, Never>()
        let proxy = SessionVerificationControllerProxyMock()
        proxy.actionsPublisher = actions.eraseToAnyPublisher()
        proxy.requestDeviceVerificationReturnValue = .success(())
        proxy.startSasVerificationReturnValue = .success(())
        proxy.approveVerificationReturnValue = .success(())
        proxy.declineVerificationReturnValue = .success(())
        proxy.cancelVerificationReturnValue = .success(())
        return (SessionVerificationScreenViewModel(controllerProxy: proxy), proxy, actions)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail.** They should fail to build.

- [ ] **Step 3: Implement**

Add to `WatchStrings`:

```swift
    static let verifyTitle = "Verify this watch"
    static let verifyIntro = "Open Element X on your iPhone to accept, then compare the emojis."
    static let verifyStart = "Start"
    static let notNow = "Not now"
    static let verifyWaiting = "Accept the request on your iPhone…"
    static let verifyCompare = "Do these match your iPhone?"
    static let theyMatch = "They match"
    static let theyDontMatch = "They don't match"
    static let verified = "This watch is verified."
    static let verificationDeclined = "The emojis didn't match, so this watch wasn't verified."
    static let verificationCancelled = "Verification was cancelled."
    static let verificationFailed = "Verification failed."
    static let done = "Done"
```

(`WatchStrings.verified` already exists as "Verified session" for Settings. Name the new one `verificationSucceeded` instead to avoid the clash, and use that name in the view below.)

`SessionVerificationScreenModels.swift`:

```swift
enum SessionVerificationStep: Equatable {
    case intro
    case waitingForAcceptance
    case startingSas
    case comparing(VerificationData)
    case confirming
    case verified
    case declined
    case cancelled
    case failed
}

struct SessionVerificationScreenViewState: BindableState {
    var step: SessionVerificationStep = .intro
}

enum SessionVerificationScreenViewAction {
    case start
    case match
    case noMatch
    case cancel
    case tryAgain
    case dismiss
}

enum SessionVerificationScreenViewModelAction {
    case dismiss
}
```

`SessionVerificationScreenViewModel.swift`:

```swift
import Combine
import Foundation

typealias SessionVerificationScreenViewModelType = StateStoreViewModelV2<SessionVerificationScreenViewState, SessionVerificationScreenViewAction>

final class SessionVerificationScreenViewModel: SessionVerificationScreenViewModelType, SessionVerificationScreenViewModelProtocol {
    private let controllerProxy: SessionVerificationControllerProxyProtocol?
    private let actionsSubject = PassthroughSubject<SessionVerificationScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<SessionVerificationScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(controllerProxy: SessionVerificationControllerProxyProtocol?) {
        self.controllerProxy = controllerProxy
        super.init(initialViewState: SessionVerificationScreenViewState())

        controllerProxy?.actionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in self?.handle(action) }
            .store(in: &cancellables)
    }

    override func process(viewAction: SessionVerificationScreenViewAction) {
        switch viewAction {
        case .start, .tryAgain:
            start()
        case .match:
            state.step = .confirming
            perform(\.approveVerification)
        case .noMatch:
            state.step = .declined
            perform(\.declineVerification)
        case .cancel:
            state.step = .cancelled
            perform(\.cancelVerification)
        case .dismiss:
            actionsSubject.send(.dismiss)
        }
    }

    private func start() {
        guard controllerProxy != nil else {
            state.step = .failed
            return
        }
        state.step = .waitingForAcceptance
        perform(\.requestDeviceVerification)
    }

    private func handle(_ action: SessionVerificationControllerProxyAction) {
        switch action {
        case .acceptedVerificationRequest:
            state.step = .startingSas
            perform(\.startSasVerification)
        case .startedSasVerification:
            break
        case .receivedVerificationData(let data):
            state.step = .comparing(data)
        case .finished:
            // A decline also finishes the flow on some SDK versions; keep the declined message.
            if state.step != .declined { state.step = .verified }
        case .cancelled:
            if state.step != .declined { state.step = .cancelled }
        case .failed:
            state.step = .failed
        }
    }

    private func perform(_ operation: KeyPath<SessionVerificationControllerProxyProtocol, () async -> Result<Void, SessionVerificationControllerProxyError>>) {
        guard let controllerProxy else { return }
        let call = controllerProxy[keyPath: operation]
        Task {
            if case .failure = await call(), state.step != .declined, state.step != .cancelled {
                state.step = .failed
            }
        }
    }
}
```

If key paths to async protocol methods don't compile, replace `perform(\.x)` with small explicit `Task { if case .failure = await controllerProxy.x() … }` calls. Keep the same failure rule: a failed call shows `.failed`, except after a user-initiated decline or cancel.

The coordinator and protocol follow the pattern (`init(controllerProxy:)`, `actionsPublisher`, `toPresentable()`).

`View/SessionVerificationScreen.swift`:

```swift
import SwiftUI

struct SessionVerificationScreen: View {
    let context: SessionVerificationScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(WatchStrings.verifyTitle)
    }

    @ViewBuilder
    private var content: some View {
        switch context.viewState.step {
        case .intro:
            Text(WatchStrings.verifyIntro).multilineTextAlignment(.center)
            Button(WatchStrings.verifyStart) { context.send(viewAction: .start) }.tint(Color.compound.bgAccentRest)
            Button(WatchStrings.notNow) { context.send(viewAction: .dismiss) }
        case .waitingForAcceptance, .startingSas:
            ProgressView()
            Text(WatchStrings.verifyWaiting).multilineTextAlignment(.center)
            Button(WatchStrings.cancel) { context.send(viewAction: .cancel) }
        case .comparing(let data):
            Text(WatchStrings.verifyCompare).font(.headline).multilineTextAlignment(.center)
            dataView(data)
            Button(WatchStrings.theyMatch) { context.send(viewAction: .match) }.tint(Color.compound.bgAccentRest)
            Button(WatchStrings.theyDontMatch, role: .destructive) { context.send(viewAction: .noMatch) }
        case .confirming:
            ProgressView()
        case .verified:
            Text(WatchStrings.verificationSucceeded).multilineTextAlignment(.center)
            Button(WatchStrings.done) { context.send(viewAction: .dismiss) }
        case .declined:
            Text(WatchStrings.verificationDeclined).multilineTextAlignment(.center)
            Button(WatchStrings.done) { context.send(viewAction: .dismiss) }
        case .cancelled, .failed:
            Text(context.viewState.step == .failed ? WatchStrings.verificationFailed : WatchStrings.verificationCancelled)
                .multilineTextAlignment(.center)
            Button(WatchStrings.tryAgain) { context.send(viewAction: .tryAgain) }
            Button(WatchStrings.notNow) { context.send(viewAction: .dismiss) }
        }
    }

    @ViewBuilder
    private func dataView(_ data: VerificationData) -> some View {
        switch data {
        case .emojis(let emojis):
            ForEach(emojis) { emoji in
                HStack {
                    Text(emoji.symbol).font(.title3)
                    Text(emoji.description).font(.footnote)
                    Spacer()
                }
            }
        case .decimals(let values):
            Text(values.map(String.init).joined(separator: " ")).font(.title3.monospacedDigit())
        }
    }
}

// MARK: - Previews

struct SessionVerificationScreen_Previews: PreviewProvider {
    static let emojis = ["🐶 Dog", "🔑 Key", "🎸 Guitar", "🌵 Cactus", "⚓️ Anchor", "🍕 Pizza", "🚀 Rocket"].map {
        VerificationEmoji(symbol: String($0.prefix(1)), description: String($0.dropFirst(2)))
    }

    static var previews: some View {
        ForEach(steps, id: \.0) { name, step in
            NavigationStack { SessionVerificationScreen(context: makeViewModel(step).context) }
                .previewDisplayName(name)
        }
    }

    static let steps: [(String, SessionVerificationStep)] = [
        ("Intro", .intro),
        ("Waiting", .waitingForAcceptance),
        ("Emojis", .comparing(.emojis(emojis))),
        ("Decimals", .comparing(.decimals([1234, 5678, 9012]))),
        ("Verified", .verified),
        ("Declined", .declined),
        ("Cancelled", .cancelled),
        ("Failed", .failed)
    ]

    static func makeViewModel(_ step: SessionVerificationStep) -> SessionVerificationScreenViewModel {
        let viewModel = SessionVerificationScreenViewModel(controllerProxy: nil)
        viewModel.state.step = step
        return viewModel
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass.** Run the standard command: 6 new tests plus the rest pass, with no warnings.

- [ ] **Step 5: Commit**: "Add the emoji verification screen", with a description and the trailers.

---

### Task 7: Present verification after password sign-in and from Settings, plus TESTING.md

**Files:**
- Modify: `ElementXWatch/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift`
- Modify: `ElementXWatch/Sources/Screens/SettingsScreen/{SettingsScreenModels,SettingsScreenViewModel}.swift`, `…/SettingsScreen/View/SettingsScreen.swift`, `SettingsScreenCoordinator.swift`
- Modify: `TESTING.md`
- Test: `UnitTests/Sources/UserSessionFlowCoordinatorTests.swift`, `UnitTests/Sources/SettingsScreenViewModelTests.swift` (additions)

**Interfaces:**
- Consumes: `SessionVerificationScreenCoordinator(controllerProxy:)` (Task 6); `ClientProxyProtocol.sessionVerificationController()` (Task 5); the `showsVerificationOnStart` parameter added in Task 4.
- Produces:
  ```swift
  // UserSessionFlowCoordinator
  init(clientProxy: ClientProxyProtocol, showsVerificationOnStart: Bool = false)
  var isPresentingVerification: Bool { get }     // test hook
  func presentVerification()
  // Settings
  SettingsScreenViewAction.verifySession, SettingsScreenViewModelAction.verifySession, SettingsScreenViewState.canVerify (verification == .unverified)
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/UserSessionFlowCoordinatorTests.swift`:

```swift
@testable import ElementXWatch
import Testing

@Suite
struct UserSessionFlowCoordinatorTests {
    @Test
    func passwordSignInPresentsVerification() async throws {
        let setup = Setup()
        setup.clientProxy.sessionVerificationControllerReturnValue = SessionVerificationControllerProxyMock.idle
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy, showsVerificationOnStart: true)

        coordinator.start()

        try await waitUntil { coordinator.isPresentingVerification }
    }

    @Test
    func restoredSessionsDoNotPresentVerification() async {
        let setup = Setup()
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy)

        coordinator.start()
        for _ in 0..<10 { await Task.yield() }

        #expect(!coordinator.isPresentingVerification)
    }

    @Test
    func dismissingVerificationHidesIt() async throws {
        let setup = Setup()
        setup.clientProxy.sessionVerificationControllerReturnValue = SessionVerificationControllerProxyMock.idle
        let coordinator = UserSessionFlowCoordinator(clientProxy: setup.clientProxy)
        coordinator.start()

        coordinator.presentVerification()
        try await waitUntil { coordinator.isPresentingVerification }
        coordinator.verificationScreen?.send(viewAction: .dismiss)

        try await waitUntil { !coordinator.isPresentingVerification }
    }
}
```

Add `SessionVerificationControllerProxyMock.idle` to `UnitTests/Sources/Support/TestFixtures.swift`: a mock with `actionsPublisher = Empty().eraseToAnyPublisher()` and every `…ReturnValue = .success(())`. Use `@MainActor static var` (the mock-extension isolation quirk noted in sub-project 1).

The `restoredSessionsDoNotPresentVerification` yield loop checks for the *absence* of an event. That's acceptable only because `start()` presents synchronously when asked. If it doesn't in your implementation, assert on a deterministic signal instead, for example that `sessionVerificationControllerCallsCount == 0`, and use that.

Add to `SettingsScreenViewModelTests.swift`:

```swift
    @Test
    func unverifiedSessionsCanVerify() async throws {
        let setup = Setup()
        setup.verification.send(.unverified)
        let viewModel = SettingsScreenViewModel(clientProxy: setup.clientProxy)
        var requested = false
        let cancellable = viewModel.actionsPublisher.sink { if case .verifySession = $0 { requested = true } }

        try await waitUntil { viewModel.context.viewState.canVerify }
        viewModel.context.send(viewAction: .verifySession)

        #expect(requested)
        setup.verification.send(.verified)
        try await waitUntil { !viewModel.context.viewState.canVerify }
        cancellable.cancel()
    }
```

- [ ] **Step 2: Run the tests to verify they fail.** They should fail to build.

- [ ] **Step 3: Implement**

**Settings.**
- Add `case verifySession` to `SettingsScreenViewAction` and to `SettingsScreenViewModelAction`, and `var canVerify: Bool { verification == .unverified }` to the state.
- `process(.verifySession)` sends `.verifySession`.
- In `SettingsScreen`, the first section shows `Button(WatchStrings.verifyTitle) { context.send(viewAction: .verifySession) }` when `canVerify`.
- Add a preview case for "Unverified with verify row" (the existing Unverified preview now shows the row).

**UserSessionFlowCoordinator.**
- Store `showsVerificationOnStart`.
- Add `var verification: SessionVerificationScreenCoordinator?` to its `Navigation` (`@Observable`).
- Test hooks: `var isPresentingVerification: Bool { navigation.verification != nil }` and `var verificationScreen: SessionVerificationScreenViewModel.Context? { navigation.verification?.context }` (give `SessionVerificationScreenCoordinator` an internal `context`).
- `start()` calls `presentVerification()` when `showsVerificationOnStart`.
- The settings sink handles `.verifySession` with `presentVerification()`.
- `presentVerification()`:

```swift
    func presentVerification() {
        guard navigation.verification == nil else { return }
        Task { [weak self, clientProxy] in
            let controllerProxy = await clientProxy.sessionVerificationController()
            guard let self else { return }
            let coordinator = SessionVerificationScreenCoordinator(controllerProxy: controllerProxy)
            coordinator.actionsPublisher
                .sink { [weak self] action in
                    switch action {
                    case .dismiss: self?.navigation.verification = nil
                    }
                }
                .store(in: &cancellables)
            navigation.verification = coordinator
        }
    }
```

- In `UserSessionFlowView`, add `.sheet(isPresented:)` bound to `navigation.verification != nil`, with the setter clearing it on swipe-down. Its content is `NavigationStack { verification.toPresentable() }`.

**TESTING.md.**
- In "How to install", replace the Team ID instruction with: "Find your Team ID in the Apple Development certificate: `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject` and use the `OU=` value (Xcode doesn't show it for Personal Teams)."
- Replace the checklist's sign-in row (row 1) with three rows:
  1. "Server screen shows `matrix.org`; Continue shows **Sign in with password** only (matrix.org has no QR sign-in)."
  2. "Password sign-in works; a wrong password shows 'Wrong username or password.' and keeps the username."
  3. "Verify: Start, then accept on the iPhone. The 7 emojis match on both devices, They match gives Verified, and older encrypted DM history decrypts. Also: Not now opens chats, and Settings shows *Verify this watch* until verified."
- Renumber the rows.

- [ ] **Step 4: Run the tests to verify they pass.** Run the standard command (full suite), with no warnings.

- [ ] **Step 5: Smoke run.** In the watchOS 26.5 simulator: launch, Server screen, Continue (real matrix.org). Screenshot the method screen, which should show only **Sign in with password**. Don't sign in with real credentials.

- [ ] **Step 6: Commit**: "Offer emoji verification after password sign-in and from Settings", with a description and the trailers.
