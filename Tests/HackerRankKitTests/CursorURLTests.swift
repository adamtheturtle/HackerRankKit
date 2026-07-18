//
//  CursorURLTests.swift
//  HackerRankKitTests
//
//  Pagination cursors come from the server's `next` links, and real responses can hand
//  back links the strict URL parser rejects (an unencoded space where a search link
//  echoes the query) or links relative to the API host. The client tolerates both, so a
//  follow-up page never fails on a link the server itself produced.
//

import Foundation
@testable import HackerRankKit
import Testing

@Suite("Pagination cursor parsing")
struct CursorURLTests {
    private let client = HackerRankClient(token: "test-token")

    @Test
    func `a well-formed absolute cursor is used as-is`() throws {
        let cursor = "https://www.hackerrank.com/x/api/v3/teams?limit=100&offset=100"
        let url = try client.pageURL(path: "/x/api/v3/teams", cursor: cursor)
        #expect(url.absoluteString == cursor)
    }

    @Test
    func `an unencoded space in a cursor is percent-encoded rather than rejected`() throws {
        let cursor = "https://www.hackerrank.com/x/api/v3/users/search?search=adam d&offset=100"
        let url = try client.pageURL(path: "/x/api/v3/users/search", cursor: cursor)
        #expect(url.absoluteString.contains("search=adam%20d"))
    }

    @Test
    func `a host-relative cursor resolves against the base URL`() throws {
        let url = try client.pageURL(path: "/x/api/v3/teams", cursor: "/x/api/v3/teams?limit=100&offset=100")
        #expect(url.absoluteString == "https://www.hackerrank.com/x/api/v3/teams?limit=100&offset=100")
    }

    @Test
    func `a cursor naming another host is rejected`() {
        for cursor in [
            "https://attacker.example/steal",
            "https://www.hackerrank.com.attacker.example/x/api/v3/teams",
            "http://www.hackerrank.com/x/api/v3/teams",
            "https://www.hackerrank.com:8443/x/api/v3/teams"
        ] {
            #expect(client.cursorURL(cursor) == nil, "expected \(cursor) to be rejected")
        }
    }

    @Test
    func `a cursor on the base URL host is accepted regardless of case`() throws {
        let url = try #require(client.cursorURL("https://WWW.HackerRank.com/x/api/v3/teams?limit=100"))
        #expect(url.absoluteString.contains("/x/api/v3/teams"))
    }

    @Test
    func `a cursor on a custom base URL host is accepted`() throws {
        let regional = HackerRankClient(
            token: "test-token",
            baseURL: try #require(URL(string: "https://eu.hackerrank.example"))
        )
        #expect(regional.cursorURL("https://eu.hackerrank.example/x/api/v3/teams") != nil)
        #expect(regional.cursorURL("https://www.hackerrank.com/x/api/v3/teams") == nil)
    }

    @Test
    func `following a foreign-host cursor never puts the token on the wire`() async throws {
        let (client, recorder) = RecordedClient.make()

        await #expect {
            _ = try await client.testsPage(after: "https://attacker.example/steal")
        } throws: { error in
            guard case let HackerRankError.http(status, body) = error else { return false }

            return status == 0 && body.hasPrefix("Invalid next-page URL")
        }

        // Not "no Authorization header sent to attacker.example" — no request at all.
        #expect(recorder.requests.isEmpty)
    }

    @Test
    func `following a same-host cursor still sends the token`() async throws {
        let (client, recorder) = RecordedClient.make()

        _ = try await client.testsPage(after: "https://www.hackerrank.com/x/api/v3/tests?offset=100")

        #expect(recorder.urls == ["https://www.hackerrank.com/x/api/v3/tests?offset=100"])
        #expect(recorder.requests.first?.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)
    }

    @Test
    func `an unusable cursor still fails with a status-zero error naming the link`() {
        do {
            _ = try client.pageURL(path: "/x/api/v3/teams", cursor: "")
            Issue.record("expected an invalid-cursor error")
        } catch let HackerRankError.http(status, body) {
            #expect(status == 0)
            #expect(body.hasPrefix("Invalid next-page URL"))
        } catch {
            Issue.record("expected HackerRankError, got \(error)")
        }
    }
}
