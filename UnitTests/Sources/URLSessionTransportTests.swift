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
struct URLSessionTransportTests {
    // Disabled: on this simulator (confirmed watchOS 27.0 and 26.5), StubURLProtocol.canInit(with:)
    // is asked once and answers true for a PUT/POST task, but startLoading() never fires - the
    // loading system routes the task to a real connection anyway. GET/HEAD are unaffected (see the
    // other tests below, and networkFailuresBecomeTransportErrors in particular). Reproduced
    // identically across .default/.ephemeral session configs, data(for:)/dataTask(with:), with/
    // without a delegate, and against a deliberately unresolvable host, so it isn't fixable from
    // this file. See task-8-report.md for the full investigation.
    @Test(.disabled("StubURLProtocol never intercepts PUT/POST on this simulator - see task-8-report.md"))
    func forwardsRequestAndResponse() async throws {
        StubURLProtocol.install { _, _ in
            (.stub(URL(string: "https://example.org/_matrix/client/v3/sync"), status: 201, headers: ["ETag": "abc"]), Data("world".utf8))
        }
        let transport = URLSessionTransport(configuration: StubURLProtocol.configuration())

        let response = try await transport.execute(request: .init(method: "PUT",
                                                                  url: "https://example.org/_matrix/client/v3/sync?since=1",
                                                                  headers: [.init(name: "Authorization", value: "Bearer secret")],
                                                                  body: Data("hello".utf8),
                                                                  timeoutMs: nil))

        let (sentRequest, sentBody) = try #require(StubURLProtocol.lastRequest)
        #expect(sentRequest.httpMethod == "PUT")
        #expect(sentRequest.url?.absoluteString == "https://example.org/_matrix/client/v3/sync?since=1")
        #expect(sentRequest.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(sentBody == Data("hello".utf8))
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
