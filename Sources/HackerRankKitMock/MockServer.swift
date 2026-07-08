//
//  MockServer.swift
//  HackerRankKit
//
//  In-process URLProtocol that fakes the HackerRank for Work API with canned data,
//  so an app can run in a demo mode without a real token or network.
//

import Foundation

/// An in-process fake of the HackerRank for Work API, served over `URLProtocol` with
/// canned fixtures, so an app can run in a demo mode and tests can run with no real
/// token or network. Pair it with ``HackerRankKit/HackerRankClient/mock(unauthorized:key:)``.
public nonisolated enum MockServer {
    static let host = "www.hackerrank.com"

    /// A session backed by the in-process fake API. When `unauthorized` is true the
    /// server answers every request with 401, which drives the "bad token" demo: the
    /// unauthorized banner and error states can be shown without a real revoked token.
    public static func session(unauthorized: Bool = false) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        let proto: URLProtocol.Type = unauthorized ? MockUnauthorizedURLProtocol.self : MockURLProtocol.self
        config.protocolClasses = [proto] + (config.protocolClasses ?? [])
        return URLSession(configuration: config)
    }
}

/// Answers every HackerRank request with 401 Unauthorized, mimicking a revoked or
/// invalid token. Backs the "bad token" demo account.
final nonisolated class MockUnauthorizedURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == MockServer.host
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let body = Data(#"{"error":"Invalid or expired token"}"#.utf8)
        guard let response = HTTPURLResponse(
            url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Serves the canned fixtures for the HackerRank endpoints, routing each request to
/// ``MockResponses``.
final nonisolated class MockURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == MockServer.host
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let method = request.httpMethod ?? "GET"
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value } ?? [:]
        let (status, body) = MockResponses.respond(method: method, url: url, query: query)

        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
