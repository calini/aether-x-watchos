//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// Executes the Rust SDK's HTTP requests with `URLSession`, the only networking watchOS permits (TN3135).
nonisolated final class URLSessionTransport: HttpTransport {
    /// Used when the SDK gives no timeout; longer than a sync long-poll so it's never cut short.
    static let fallbackTimeout: TimeInterval = 120
    /// The session's resource timeout, which caps every request anyway. The SDK's media fetcher asks for
    /// `Duration::MAX` (`UInt64.max` ms), which must not reach `URLRequest` as an absurd interval.
    static let maximumTimeout: TimeInterval = 300

    private let session: URLSession

    init(configuration: URLSessionConfiguration = .elementXWatch) {
        session = URLSession(configuration: configuration)
    }

    func execute(request: HttpTransportRequest) async throws -> HttpTransportResponse {
        let urlRequest = try Self.makeURLRequest(from: request)
        let path = urlRequest.url?.path() ?? ""

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HttpTransportError.Network(message: "Received a non-HTTP response")
            }
            MXLog.verbose("\(request.method) \(path) -> \(httpResponse.statusCode)")
            return HttpTransportResponse(status: UInt16(httpResponse.statusCode),
                                         headers: Self.headers(from: httpResponse),
                                         body: data)
        } catch let error as HttpTransportError {
            throw error
        } catch {
            let code = (error as? URLError)?.code.rawValue ?? -1
            MXLog.info("\(request.method) \(path) failed with URLError \(code)")
            throw HttpTransportError.Network(message: error.localizedDescription)
        }
    }

    static func makeURLRequest(from request: HttpTransportRequest) throws -> URLRequest {
        guard let url = URL(string: request.url), url.scheme != nil else {
            throw HttpTransportError.Network(message: "Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body.isEmpty ? nil : request.body
        urlRequest.timeoutInterval = request.timeoutMs.map { min(max(TimeInterval($0) / 1000, 1), maximumTimeout) } ?? fallbackTimeout
        for header in request.headers {
            urlRequest.addValue(header.value, forHTTPHeaderField: header.name)
        }
        return urlRequest
    }

    private static func headers(from response: HTTPURLResponse) -> [HttpHeader] {
        response.allHeaderFields.compactMap { key, value in
            guard let name = key as? String else { return nil }
            return HttpHeader(name: name, value: String(describing: value))
        }
    }
}

extension URLSessionConfiguration {
    /// No caching or cookies (the SDK owns both), no waiting for connectivity (the SDK owns retries).
    nonisolated static var elementXWatch: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.timeoutIntervalForResource = URLSessionTransport.maximumTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return configuration
    }
}
