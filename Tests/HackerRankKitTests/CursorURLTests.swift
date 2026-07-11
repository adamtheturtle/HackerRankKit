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
