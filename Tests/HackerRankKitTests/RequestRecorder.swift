//
//  RequestRecorder.swift
//  HackerRankKitTests
//
//  A `URLProtocol` that records every request a client actually puts on the wire and
//  answers it from a canned handler. The mock server routes on `URL.path`, which is
//  percent-*decoded*, so it cannot see how a URL was encoded; these tests need the raw
//  `absoluteString` and the request headers, which is what this records.
//

import Foundation
@testable import HackerRankKit

/// Collects the requests one client made, and supplies each response.
final nonisolated class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private var recordedBodies: [Data] = []
    private let handler: @Sendable (URL) -> (Int, Data)

    /// - Parameter handler: maps a requested URL to a status and a JSON body.
    init(handler: @escaping @Sendable (URL) -> (Int, Data) = { _ in (200, Data(#"{"data":[],"next":null}"#.utf8)) }) {
        self.handler = handler
    }

    /// Every request made so far, in the order the protocol saw them.
    var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    /// The `absoluteString` of every requested URL — the encoded form, not the decoded path.
    var urls: [String] {
        requests.compactMap(\.url?.absoluteString)
    }

    /// The JSON body of every request made so far, in order — empty for bodyless requests.
    var bodies: [Data] {
        lock.withLock { recordedBodies }
    }

    fileprivate func record(_ request: URLRequest) -> (Int, Data) {
        // The body has to be drained here, while the protocol still holds the request:
        // `URLRequest.httpBody` is nil by the time a request reaches a `URLProtocol`, and
        // the stream it is carried in can only be read once.
        let body = Self.body(of: request)
        lock.withLock {
            recorded.append(request)
            recordedBodies.append(body)
        }
        guard let url = request.url else { return (0, Data()) }

        return handler(url)
    }

    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }

        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }

            data.append(buffer, count: read)
        }
        return data
    }
}

/// Hands out a client whose session records into a fresh ``RequestRecorder``.
enum RecordedClient {
    /// A registry keyed by Bearer token, so suites running in parallel never see each
    /// other's requests. `nonisolated(unsafe)` with an explicit lock because `URLProtocol`
    /// subclasses are instantiated by `URLSession` outside any actor.
    private nonisolated(unsafe) static var recorders: [String: RequestRecorder] = [:]
    private nonisolated static let lock = NSLock()

    /// A client pointed at `baseURL` whose every request is recorded and answered by
    /// `handler`, never reaching the network.
    static func make(
        baseURL: URL = URL(string: "https://www.hackerrank.com") ?? URL(fileURLWithPath: "/"),
        handler: @escaping @Sendable (URL) -> (Int, Data) = { _ in (200, Data(#"{"data":[],"next":null}"#.utf8)) }
    ) -> (client: HackerRankClient, recorder: RequestRecorder) {
        let token = "recorded-\(UUID().uuidString)"
        let recorder = RequestRecorder(handler: handler)
        lock.withLock { recorders[token] = recorder }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecordingURLProtocol.self]
        let session = URLSession(configuration: config)
        return (HackerRankClient(token: token, baseURL: baseURL, session: session), recorder)
    }

    fileprivate nonisolated static func recorder(forBearer header: String?) -> RequestRecorder? {
        guard let token = header?.replacingOccurrences(of: "Bearer ", with: "") else { return nil }

        return lock.withLock { recorders[token] }
    }
}

/// Routes every request in a recorded session to its ``RequestRecorder``.
final nonisolated class RecordingURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let recorder = RecordedClient.recorder(
                  forBearer: request.value(forHTTPHeaderField: "Authorization")
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let (status, body) = recorder.record(request)
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
