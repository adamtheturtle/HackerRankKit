//
//  ModelTests.swift
//  HackerRankKitTests
//
//  Pure value-type behavior: resilient decoding, the lenient page envelope, and the
//  error type's classification. No network.
//

import Foundation
import HackerRankKit
import Testing

@Suite("Model decoding")
struct ModelDecodingTests {
    private func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    @Test
    func `test decodes with snake_case keys`() throws {
        let json = #"""
        {"id":"t1","unique_id":"abc","name":"Backend Screen","cutoff_score":70,"shuffle_questions":true}
        """#
        let test = try decode(HackerRankKit.Test.self, json)
        #expect(test.id == "t1")
        #expect(test.uniqueID == "abc")
        #expect(test.cutoffScore == 70)
        #expect(test.shuffleQuestions == true)
    }

    @Test
    func `page drops invalid elements but keeps valid ones`() throws {
        // The middle element is missing the required `id`, so the lenient page decoder
        // drops it while keeping the two valid tests and the `next` cursor.
        let json = #"""
        {"data":[{"id":"t1","name":"One"},{"name":"No id"},{"id":"t3","name":"Three"}],
         "next":"https://example.com/next","total":3}
        """#
        let page = try decode(HackerRankPage<HackerRankKit.Test>.self, json)
        #expect(page.data.map(\.id) == ["t1", "t3"])
        #expect(page.next == "https://example.com/next")
        #expect(page.totalCount == 3)
    }

    @Test
    func `user without email still decodes`() throws {
        let page = try decode(HackerRankPage<User>.self, #"{"data":[{"id":"u1"}],"next":null}"#)
        #expect(page.data.count == 1)
        #expect(page.data.first?.email == "")
    }

    @Test
    func `interview person decodes bare string and object`() throws {
        let json = #"""
        {"from":"2026-01-01T09:00:00Z",
         "interviewers":["alice@example.com",{"firstname":"Bob","lastname":"Jones"}]}
        """#
        let detail = try decode(InterviewDetail.self, json)
        #expect(detail.interviewers.count == 2)
        #expect(detail.interviewers[0].email == "alice@example.com")
        #expect(detail.interviewers[1].displayName == "Bob Jones")
        #expect(detail.hasPeople)
    }

    @Test
    func `audit log accepts a numeric source id`() throws {
        let entry = try decode(AuditLogEntry.self, #"{"source_id":42,"source_type":"test","action":"update"}"#)
        #expect(entry.sourceID == "42")
        #expect(entry.headline == "Update test 42")
        #expect(entry.actionSymbol == "pencil")
    }
}

@Suite("HackerRankError")
struct HackerRankErrorTests {
    @Test
    func `unauthorized recognizes 401 and 403`() {
        #expect(HackerRankError.http(401, "").isUnauthorized)
        #expect(HackerRankError.http(403, "").isUnauthorized)
        #expect(!HackerRankError.http(404, "").isUnauthorized)
        #expect(!HackerRankError.decode("x").isUnauthorized)
    }

    @Test
    func `description carries the status and body`() {
        #expect(HackerRankError.http(500, "boom").description == "HTTP 500: boom")
        #expect(HackerRankError.missingAPIKey.description == "Missing API key.")
    }
}
