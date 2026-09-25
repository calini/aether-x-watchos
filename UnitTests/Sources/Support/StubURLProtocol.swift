//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import Foundation
import Synchronization

/// Intercepts URLSession traffic in tests. Install a handler before each test.
nonisolated final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest, Data?) throws -> (HTTPURLResponse, Data)

    private static let state = Mutex<(handler: Handler?, lastRequest: (URLRequest, Data?)?)>((nil, nil))

    static var lastRequest: (URLRequest, Data?)? {
        state.withLock { $0.lastRequest }
    }

    static func install(_ handler: @escaping Handler) {
        state.withLock { $0 = (handler, nil) }
    }

    static func configuration() -> URLSessionConfiguration {
        // .ephemeral, not .elementXWatch: on this simulator (confirmed on watchOS 27.0 and 26.5) a
        // session built from URLSessionConfiguration.default only sometimes consults a registered
        // URLProtocol at all, even for GET.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.protocolClasses = [StubURLProtocol.self]
        // Route any request our protocol doesn't end up handling into a dead end: on this simulator
        // the loading system can fall back to (or race) a live network fetch alongside a registered
        // URLProtocol, which would otherwise silently hit example.org.
        configuration.connectionProxyDictionary = [
            "HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": 1,
            "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": 1
        ]
        return configuration
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        let handler = Self.state.withLock { state in
            state.lastRequest = (request, body)
            return state.handler
        }
        do {
            guard let handler else { throw URLError(.resourceUnavailable) }
            let (response, data) = try handler(request, body)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

extension HTTPURLResponse {
    nonisolated static func stub(_ url: URL?, status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: url ?? URL(string: "https://example.org")!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    }
}
