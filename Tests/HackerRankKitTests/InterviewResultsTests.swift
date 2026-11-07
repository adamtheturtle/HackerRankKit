import Foundation
@testable import HackerRankKit
import HackerRankKitMock
import Testing

@Suite("Interviews V2 and audit cursor contract")
struct InterviewResultsTests {
    @Test
    func `artifacts and notes decode from the mock`() async throws {
        let client = HackerRankClient.mock()
        guard case let .available(artifacts) = try await client.interviewArtifacts(id: "iv1") else {
            Issue.record("Expected completed artifact metadata")
            return
        }
        #expect(artifacts.questions.first?.questionName == "Demo coding task")
        #expect(artifacts.transcriptURL.location == nil)
        let notes = try await client.interviewNotes(id: "iv1", noteIDs: [1])
        #expect(notes.first?.editable == true)
        let saved = try await client.updateInterviewNote(id: "iv1", content: "")
        #expect(saved.updatedAt != nil)
    }

    @Test
    func `pending artifacts remain a pending result`() async throws {
        let (client, recorder) = RecordedClient.make(responseHeaders: ["Retry-After": "180"]) { _ in
            (202, Data(#"{"message":"Still generating"}"#.utf8))
        }
        guard case let .pending(pending) = try await client.interviewArtifacts(id: "123/encoded") else {
            Issue.record("Expected pending response")
            return
        }
        #expect(pending.message == "Still generating")
        #expect(pending.retryAfter == 180)
        #expect(recorder.urls.first?.contains("123%2Fencoded/artifacts") == true)
        #expect(recorder.requests.count == 1)
    }

    @Test
    func `notes send CSV ids and exact content`() async throws {
        let (client, recorder) = RecordedClient.make { _ in
            (200, Data(#"{"notes":[],"content":"","updated_at":"now"}"#.utf8))
        }
        _ = try await client.interviewNotes(id: "123", noteIDs: [1, 2])
        _ = try await client.updateInterviewNote(id: "123", content: "")
        let url = try #require(recorder.requests.first?.url)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.first?.value == "1,2")
        #expect(recorder.requests.last?.httpMethod == "PATCH")
        let body = try #require(try JSONSerialization.jsonObject(with: recorder.bodies[1]) as? [String: String])
        #expect(body == ["content": ""])
    }

    @Test
    func `cursor continuation sends only the opaque token`() async throws {
        let (client, recorder) = RecordedClient.make { _ in
            (200, Data(#"{"data":[],"page_total":0,"has_more":false,"next_cursor":null}"#.utf8))
        }
        let page = try await client.auditLogCursorPage(
            cursor: "opaque+/=", filters: AuditLogFilters(sourceID: "ignored"), includeTotal: true
        )
        #expect(page.nextCursor == nil)
        #expect(page.total == nil)
        let url = try #require(recorder.requests.first?.url)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query == [URLQueryItem(name: "cursor", value: "opaque+/=")])
    }

    @Test
    func `initial cursor request uses documented filters`() async throws {
        let (client, recorder) = RecordedClient.make { _ in
            (200, Data(#"{"data":[],"page_total":0,"has_more":true,"next_cursor":"next","total":12000}"#.utf8))
        }
        let page = try await client.auditLogCursorPage(
            filters: AuditLogFilters(user: "2", sourceType: "test", sourceID: "3"), includeTotal: true
        )
        #expect(page.total == 12000)
        let url = try #require(recorder.requests.first?.url)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.contains(URLQueryItem(name: "user", value: "2")))
        #expect(!query.contains(where: { $0.name == "user_id" }))
        #expect(query.contains(URLQueryItem(name: "include_total", value: "true")))
    }

    @Test
    func `template question operations use the documented body and query`() async throws {
        let (client, recorder) = RecordedClient.make { _ in
            (200, Data(#"{"id":"123","name":"Demo","questions":[4,5]}"#.utf8))
        }
        _ = try await client.addQuestionsToInterviewTemplate(id: 123, questionIDs: [4, 5])
        _ = try await client.removeQuestionFromInterviewTemplate(id: 123, questionID: 4)
        #expect(recorder.requests.first?.httpMethod == "PUT")
        let body = try #require(try JSONSerialization.jsonObject(with: recorder.bodies[0]) as? [String: [Int]])
        #expect(body == ["question_ids": [4, 5]])
        #expect(recorder.requests.last?.httpMethod == "DELETE")
        #expect(recorder.urls.last?.hasSuffix("remove_question?question_id=4") == true)
    }

    @Test
    func `resource JSON preserves unknown fields and rejects foreign cursors`() async throws {
        let (client, recorder) = RecordedClient.make { _ in
            (200, Data(#"{"new_field":{"nested":[1,true,null]}}"#.utf8))
        }
        let value = try await client.resourceJSON(path: "/x/api/v3/tests/123")
        guard case let .object(fields) = value else {
            Issue.record("Expected complete JSON object")
            return
        }
        #expect(fields["new_field"] != nil)
        do {
            _ = try await client.resourceJSON(path: "/x/api/v3/tests", after: "https://example.com/steal")
            Issue.record("Expected foreign cursor rejection")
        } catch let error as HackerRankError {
            guard case .http(0, _) = error else { throw error }
        }
        #expect(recorder.requests.count == 1)
    }

    @Test
    func `offset metadata and current filter are retained`() async throws {
        let (client, recorder) = RecordedClient.make { _ in
            (200, Data(#"{"data":[],"next":null,"offset_window_limit":10000,"offset_window_exhausted":true}"#.utf8))
        }
        let page = try await client.auditLogOffsetPage(filters: AuditLogFilters(user: "2"))
        #expect(page.offsetWindowLimit == 10000)
        #expect(page.offsetWindowExhausted == true)
        #expect(recorder.urls.first?.contains("user=2") == true)
    }

    @Test(arguments: [400, 410])
    func `cursor failures preserve the status`(status: Int) async throws {
        let (client, _) = RecordedClient.make { _ in
            (status, Data(#"{"errors":["Cursor invalid or expired"]}"#.utf8))
        }
        do {
            _ = try await client.auditLogCursorPage(cursor: "expired")
            Issue.record("Expected cursor error")
        } catch let error as HackerRankError {
            guard case let .http(actual, _) = error else { throw error }
            #expect(actual == status)
        }
    }
}
