//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

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

    @Test
    func configureInterleavedWithALaterConfigureDoesNotOrphanTheStaleDirectories() async throws {
        StubURLProtocol.install { request, _ in Self.homeserver(request, loginTypes: ["m.login.password"], msc4108: false) }
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let realFactory = ClientFactory(transport: URLSessionTransport(configuration: StubURLProtocol.configuration()),
                                        sessionDelegate: SessionDelegate(keychainStore: keychain))
        let factory = ClientFactoryMock()
        let gate = AsyncGate()
        // Only the first (stale) call is held open; the second one that supersedes it runs straight through.
        factory.makeLoginClientServerNameDirectoriesPassphraseClosure = { serverName, directories, passphrase in
            if serverName == "https://a.example.org" { await gate.wait() }
            return try await realFactory.makeLoginClient(serverName: serverName, directories: directories, passphrase: passphrase)
        }
        let service = AuthenticationService(clientFactory: factory, sessionStore: SessionStore(keychainStore: keychain))

        let staleConfigure = Task { await service.configure(server: "https://a.example.org") }
        try await waitUntil { factory.makeLoginClientServerNameDirectoriesPassphraseCallsCount == 1 }
        let staleDirectories = factory.makeLoginClientServerNameDirectoriesPassphraseReceivedInvocations[0].directories
        #expect(FileManager.default.fileExists(atPath: staleDirectories.dataPath))

        let latestOptions = try await service.configure(server: "https://b.example.org").get()
        #expect(latestOptions.serverName == "b.example.org")
        let latestDirectories = factory.makeLoginClientServerNameDirectoriesPassphraseReceivedInvocations[1].directories
        #expect(FileManager.default.fileExists(atPath: latestDirectories.dataPath))

        await gate.open()
        let staleResult = await staleConfigure.value
        #expect(staleResult.failureValue == .unknown)
        #expect(!FileManager.default.fileExists(atPath: staleDirectories.dataPath))

        // pendingLogin still belongs to the latest configure: reset() finds and deletes ITS directories.
        #expect(FileManager.default.fileExists(atPath: latestDirectories.dataPath))
        service.reset()
        #expect(!FileManager.default.fileExists(atPath: latestDirectories.dataPath))
    }

    // MARK: - Helpers

    private func makeService() -> AuthenticationService {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let factory = ClientFactory(transport: URLSessionTransport(configuration: StubURLProtocol.configuration()),
                                    sessionDelegate: SessionDelegate(keychainStore: keychain))
        return AuthenticationService(clientFactory: factory, sessionStore: SessionStore(keychainStore: keychain))
    }

    private nonisolated static func homeserver(_ request: URLRequest, loginTypes: [String], msc4108: Bool) -> (HTTPURLResponse, Data) {
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
