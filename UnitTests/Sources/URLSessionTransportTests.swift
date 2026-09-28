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
struct URLSessionTransportTests {
    @Test
    func buildsTheRequestFromTheSDKRequest() throws {
        let request = try URLSessionTransport.makeURLRequest(from: .init(method: "PUT",
                                                                         url: "https://example.org/_matrix/client/v3/sync?since=1",
                                                                         headers: [.init(name: "Authorization", value: "Bearer secret")],
                                                                         body: Data("hello".utf8),
                                                                         timeoutMs: nil))
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.absoluteString == "https://example.org/_matrix/client/v3/sync?since=1")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.httpBody == Data("hello".utf8))
    }

    @Test
    func forwardsTheResponse() async throws {
        StubURLProtocol.install { _, _ in
            (.stub(URL(string: "https://example.org/_matrix/client/v3/sync"), status: 201, headers: ["ETag": "abc"]), Data("world".utf8))
        }
        let transport = URLSessionTransport(configuration: StubURLProtocol.configuration())

        let response = try await transport.execute(request: .init(method: "GET",
                                                                  url: "https://example.org/_matrix/client/v3/sync?since=1",
                                                                  headers: [.init(name: "Authorization", value: "Bearer secret")],
                                                                  body: Data(),
                                                                  timeoutMs: nil))

        let (sentRequest, _) = try #require(StubURLProtocol.lastRequest)
        #expect(sentRequest.httpMethod == "GET")
        #expect(sentRequest.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(response.status == 201)
        #expect(response.body == Data("world".utf8))
        #expect(response.headers.contains { $0.name.lowercased() == "etag" && $0.value == "abc" })
    }

    @Test
    func usesTheSDKTimeout() throws {
        let request = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: 45000))
        #expect(request.timeoutInterval == 45)
    }

    @Test
    func clampsAnUnboundedSDKTimeoutToTheResourceTimeout() throws {
        let request = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: UInt64.max))
        #expect(request.timeoutInterval == 300)
        #expect(URLSessionConfiguration.aetherXWatch.timeoutIntervalForResource == 300)
    }

    @Test
    func fallsBackToALongTimeoutSoLongPollsAreNotCut() throws {
        let request = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: nil))
        #expect(request.timeoutInterval == URLSessionTransport.fallbackTimeout)
        #expect(URLSessionTransport.fallbackTimeout >= 120)
    }

    @Test
    func emptyBodiesAreNotSent() throws {
        let request = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: nil))
        #expect(request.httpBody == nil)
    }

    @Test
    func networkFailuresBecomeTransportErrors() async {
        StubURLProtocol.install { _, _ in throw URLError(.notConnectedToInternet) }
        let transport = URLSessionTransport(configuration: StubURLProtocol.configuration())

        await #expect(throws: HttpTransportError.self) {
            _ = try await transport.execute(request: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: nil))
        }
    }

    @Test
    func invalidURLsAreRejected() {
        #expect(throws: HttpTransportError.self) {
            _ = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "not a url", headers: [], body: Data(), timeoutMs: nil))
        }
    }
}
