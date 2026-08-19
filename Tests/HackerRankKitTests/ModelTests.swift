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
    func `test decodes the API's unhyphenated window keys`() throws {
        let json = #"""
        {"id":"t1","name":"Screen","starttime":"2026-08-20T09:00:00+0000",
         "endtime":"2026-08-27T09:00:00+0000"}
        """#
        let test = try decode(HackerRankKit.Test.self, json)
        #expect(test.startTime == "2026-08-20T09:00:00+0000")
        #expect(test.endTime == "2026-08-27T09:00:00+0000")
    }

    @Test
    func `test decodes every documented configuration field`() throws {
        let json = #"""
        {"id":"t1","name":"Screen","locked":true,"locked_by":"u9",
         "candidate_details":["full_name","university"],
         "custom_acknowledge_text":"I agree.","hide_compile_test":true,
         "role_ids":["r1","r2"],"experience":["Senior"],"test_admins":["u1"],
         "hide_template":true,"enable_acknowledgement":true,
         "enable_advanced_proctoring":true,"enable_secure_assessment_mode":true,
         "enable_ml_plagiarism_analysis":true,"enable_photo_identification":true,
         "ide_config":"vscode"}
        """#
        let test = try decode(HackerRankKit.Test.self, json)
        #expect(test.lockedBy == "u9")
        #expect(test.candidateDetails == ["full_name", "university"])
        #expect(test.customAcknowledgeText == "I agree.")
        #expect(test.hideCompileTest == true)
        #expect(test.roleIDs == ["r1", "r2"])
        #expect(test.experience == ["Senior"])
        #expect(test.testAdmins == ["u1"])
        #expect(test.hideTemplate == true)
        #expect(test.enableAcknowledgement == true)
        #expect(test.enableAdvancedProctoring == true)
        #expect(test.enableSecureAssessmentMode == true)
        #expect(test.enableMLPlagiarismAnalysis == true)
        #expect(test.enablePhotoIdentification == true)
        #expect(test.ideConfig == "vscode")
        #expect(test.roleFilterValues == ["R1", "R2"])
    }

    @Test
    func `a test whose sections are the documented object survives the page`() throws {
        // The schema documents `sections` as an object. Decoding only the array shape made a
        // conforming row throw, and the lenient page decoder then dropped the whole test.
        let json = #"""
        {"data":[{"id":"t1","name":"Screen",
          "sections":{"b":{"uuid":"s2","name":"MCQ","questions":5},
                      "a":{"name":"Coding","questions":2,"duration":60}}}],"next":null}
        """#
        let page = try decode(HackerRankPage<HackerRankKit.Test>.self, json)
        let sections = try #require(page.data.first?.sections)
        #expect(sections.map(\.slot) == ["a", "b"])
        #expect(sections.map(\.displayName) == ["Coding", "MCQ"])
        #expect(sections.map(\.id) == ["a-Coding", "s2"])
    }

    @Test
    func `array-shaped sections still decode and stay distinct`() throws {
        let json = #"""
        {"id":"t1","name":"Screen","sections":[{"questions":2},{"questions":3}]}
        """#
        let test = try decode(HackerRankKit.Test.self, json)
        let sections = try #require(test.sections)
        #expect(sections.map(\.questionCount) == [2, 3])
        // Unnamed sections used to share the constant id "section" and collide.
        #expect(sections.map(\.id) == ["0", "1"])
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
    func `page accepts the string-valued totals the v3 API sends`() throws {
        let text = try decode(HackerRankPage<User>.self, #"{"data":[],"next":null,"total":"13"}"#)
        let number = try decode(HackerRankPage<User>.self, #"{"data":[],"next":null,"total":13}"#)
        let missing = try decode(HackerRankPage<User>.self, #"{"data":[],"next":null}"#)
        let nonsense = try decode(HackerRankPage<User>.self, #"{"data":[],"next":null,"total":"many"}"#)

        #expect(text.totalCount == 13)
        #expect(number.totalCount == 13)
        #expect(missing.totalCount == nil)
        #expect(nonsense.totalCount == nil)
    }

    @Test
    func `page normalizes empty terminal cursors`() {
        let empty = Page(items: [1], next: "")
        let whitespace = Page(items: [1], next: "  \n")
        let continuation = Page(items: [1], next: "  https://example.com/next  ")

        #expect(empty.next == nil)
        #expect(whitespace.next == nil)
        #expect(continuation.next == "https://example.com/next")
    }

    @Test
    func `candidate ATS states expose the documented wire contract`() {
        #expect(CandidateATSState.allCases.map(\.rawValue) == Array(0 ... 22))
        #expect(CandidateATSState(rawValue: 2) == .qualified)
        #expect(CandidateATSState(rawValue: 21) == .hired)
        #expect(CandidateATSState(rawValue: 22) == .rejected)
        #expect(CandidateATSState(rawValue: -1) == nil)
        #expect(CandidateATSState(rawValue: 23) == nil)
    }

    @Test
    func `question lifecycle statuses expose the documented wire contract`() {
        #expect(QuestionLifecycleStatus.allCases == [.active, .archived])
        #expect(QuestionLifecycleStatus(rawValue: "active") == .active)
        #expect(QuestionLifecycleStatus(rawValue: "archived") == .archived)
        #expect(QuestionLifecycleStatus(rawValue: "published") == nil)
    }

    @Test
    func `user without email still decodes`() throws {
        let page = try decode(HackerRankPage<User>.self, #"{"data":[{"id":"u1"}],"next":null}"#)
        #expect(page.data.count == 1)
        #expect(page.data.first?.email == "")
    }

    @Test
    func `test inviter without email still decodes`() throws {
        let page = try decode(HackerRankPage<TestInviter>.self, #"{"data":[{"id":"u1"}],"next":null}"#)
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
