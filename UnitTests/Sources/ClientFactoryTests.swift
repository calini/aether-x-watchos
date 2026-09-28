//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite(.serialized)
struct ClientFactoryTests {
    @Test
    func buildsALoginClientEntirelyThroughTheTransport() async throws {
        StubURLProtocol.install { request, _ in
            switch request.url?.path() {
            case "/.well-known/matrix/client":
                return (.stub(request.url, status: 404), Data())
            case "/_matrix/client/versions":
                let body = #"{"versions":["v1.11"],"unstable_features":{"org.matrix.simplified_msc3575":true}}"#
                return (.stub(request.url, status: 200, headers: ["Content-Type": "application/json"]), Data(body.utf8))
            default:
                return (.stub(request.url, status: 404), Data(#"{"errcode":"M_UNRECOGNIZED"}"#.utf8))
            }
        }
        let directories = SessionDirectories()
        try directories.create()
        defer { directories.delete() }

        let client = try await makeFactory().makeLoginClient(serverName: "https://example.org",
                                                             directories: directories,
                                                             passphrase: Data(repeating: 7, count: 32))

        #expect(client.homeserver().hasPrefix("https://example.org"))
    }

    @Test
    func transportFailuresSurfaceAsServerUnreachable() async throws {
        StubURLProtocol.install { _, _ in throw URLError(.cannotFindHost) }
        let directories = SessionDirectories()
        try directories.create()
        defer { directories.delete() }

        // Before the SDK could lift `HttpTransportError`, this threw a Rust panic instead.
        let error = await #expect(throws: ClientBuildError.self) {
            try await makeFactory().makeLoginClient(serverName: "https://nowhere.invalid",
                                                    directories: directories,
                                                    passphrase: Data(repeating: 7, count: 32))
        }

        guard case .ServerUnreachable = error else {
            Issue.record("Expected ServerUnreachable, got \(String(describing: error))")
            return
        }
    }

    private func makeFactory() -> ClientFactory {
        ClientFactory(transport: URLSessionTransport(configuration: StubURLProtocol.configuration()),
                      sessionDelegate: SessionDelegate(keychainStore: KeychainStore(service: "tests.\(UUID().uuidString)")))
    }
}
