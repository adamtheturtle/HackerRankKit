//
//  URLEncodingTests.swift
//  HackerRankKitTests
//
//  The URL a request actually carries, for ids and search terms that are not bare
//  alphanumerics. These assert on the recorded `absoluteString` rather than on
//  `URL.path`/`queryItems`, which percent-*decode* and so hide an encoding bug.
//

import Foundation
@testable import HackerRankKit
import Testing

@Suite("Request URL encoding")
struct URLEncodingTests {
    // MARK: Path segments

    @Test
    func `an id with @ and + is percent-encoded exactly once in a path`() async throws {
        let (client, recorder) = RecordedClient.make { _ in (200, Data(#"{"id":"ada+test@example.com"}"#.utf8)) }

        _ = try await client.scimUser(id: "ada+test@example.com")

        // Exactly one encoding: `%2B`/`%40`, never the doubly-encoded `%252B`/`%2540`.
        #expect(recorder.urls == ["https://www.hackerrank.com/Users/ada%2Btest%40example.com"])
    }

    @Test
    func `a space in an id is percent-encoded exactly once in a path`() async throws {
        let (client, recorder) = RecordedClient.make { _ in (200, Data(#"{"id":"t 1","name":"n"}"#.utf8)) }

        _ = try await client.test(id: "t 1")

        #expect(recorder.urls == ["https://www.hackerrank.com/x/api/v3/tests/t%201"])
    }

    @Test
    func `an id in a write path is percent-encoded exactly once`() async throws {
        let (client, recorder) = RecordedClient.make { _ in (200, Data(#"{"id":"c@1"}"#.utf8)) }

        _ = try await client.deleteCandidateReport(testID: "t+1", candidateID: "c@1")

        #expect(recorder.urls == [
            "https://www.hackerrank.com/x/api/v3/tests/t%2B1/candidates/c%401/report"
        ])
    }

    @Test
    func `an id in a paged path is percent-encoded exactly once`() async throws {
        let (client, recorder) = RecordedClient.make()

        _ = try await client.candidatesPage(testID: "t@1")

        #expect(recorder.urls == [
            "https://www.hackerrank.com/x/api/v3/tests/t%401/candidates?limit=100"
        ])
    }

    @Test
    func `an id cannot break out of its path segment`() async throws {
        let (client, recorder) = RecordedClient.make { _ in (200, Data(#"{"id":"x","name":"n"}"#.utf8)) }

        _ = try await client.test(id: "../../admin")

        #expect(recorder.urls == ["https://www.hackerrank.com/x/api/v3/tests/..%2F..%2Fadmin"])
    }

    // MARK: Query values

    @Test
    func `a plus in a search term is percent-encoded so the server does not read it as a space`() async throws {
        let (client, recorder) = RecordedClient.make()

        _ = try await client.searchCandidates(query: "C++")

        let url = try #require(recorder.urls.first)
        #expect(url.contains("query=C%2B%2B"))
        #expect(!url.contains("C++"))
    }

    @Test
    func `a plus-addressed email survives a user search verbatim`() async throws {
        let (client, recorder) = RecordedClient.make()

        _ = try await client.searchUsers(query: "ada+test@example.com")

        // `@` is legal in a query and the backend reads it literally, so only `+` — which
        // Rack would turn into a space — needs escaping.
        let url = try #require(recorder.urls.first)
        #expect(url.contains("search=ada%2Btest@example.com"))
    }

    @Test
    func `a plus in an audit-log filter is percent-encoded`() async throws {
        let (client, recorder) = RecordedClient.make()

        _ = try await client.auditLogPage(userID: "u+1")

        let url = try #require(recorder.urls.first)
        #expect(url.contains("user_id=u%2B1"))
    }
}
