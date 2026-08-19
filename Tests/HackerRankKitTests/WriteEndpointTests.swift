//
//  WriteEndpointTests.swift
//  HackerRankKitTests
//
//  Endpoint-level coverage for the typed write bodies: the encoding tests prove a request
//  struct serialises correctly, these prove the client actually puts that body on the wire
//  at the documented method and path.
//

import Foundation
@testable import HackerRankKit
import Testing

@Suite("Write endpoints")
struct WriteEndpointTests {
    /// A client answering every write with an empty JSON object — every write echo is
    /// all-optional, so `{}` decodes and keeps these tests about the request.
    private func recordedClient() -> (client: HackerRankClient, recorder: RequestRecorder) {
        RecordedClient.make { _ in (200, Data("{}".utf8)) }
    }

    /// The single request a write made: its method, its path, and its decoded JSON body.
    private struct SentRequest {
        let method: String
        let path: String
        let body: [String: Any]
    }

    private func sentRequest(_ recorder: RequestRecorder) throws -> SentRequest {
        let request = try #require(recorder.requests.first)
        let body = try #require(recorder.bodies.first)
        return SentRequest(
            method: try #require(request.httpMethod),
            path: try #require(request.url?.path),
            body: try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        )
    }

    @Test
    func `updateCustomCodeStubs puts the typed stub list`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.updateCustomCodeStubs(
            questionID: "q1",
            stubs: [QuestionCodeStub(language: "swift", body: "func solve() {}", head: "import Foundation", tail: "")]
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "PUT")
        #expect(sent.path == "/x/api/v3/questions/q1/custom_codestubs")
        // The endpoint reads `templates`, and each template is head/body/tail.
        #expect(sent.body["custom_codestubs"] == nil)
        let stubs = try #require(sent.body["templates"] as? [[String: Any]])
        #expect(stubs.first?["language"] as? String == "swift")
        #expect(stubs.first?["head"] as? String == "import Foundation")
        #expect(stubs.first?["body"] as? String == "func solve() {}")
        #expect(stubs.first?["tail"] as? String == "")
    }

    @Test
    func `generateCodeStubs puts the signature metadata`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.generateCodeStubs(
            questionID: "q1",
            options: CodeStubGenerationOptions(
                type: "code",
                functionName: "twoSum",
                functionParams: "INTEGER_ARRAY nums INTEGER target",
                functionReturn: "INTEGER_ARRAY",
                allowedLanguages: ["c", "clojure"]
            )
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "PUT")
        #expect(sent.path == "/x/api/v3/questions/q1/generate")
        // This endpoint's keys are camelCase, and every value is a single string.
        #expect(sent.body["type"] as? String == "code")
        #expect(sent.body["functionName"] as? String == "twoSum")
        #expect(sent.body["functionParams"] as? String == "INTEGER_ARRAY nums INTEGER target")
        #expect(sent.body["functionReturn"] as? String == "INTEGER_ARRAY")
        #expect(sent.body["allowedLanguages"] as? String == "c,clojure")
        for absent in ["function_name", "return_type", "parameters", "languages"] {
            #expect(sent.body[absent] == nil, "\(absent) is not a documented generate field")
        }
    }

    @Test
    func `addTestcase posts the typed testcase body`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.addTestcase(
            questionID: "q1",
            options: QuestionTestcaseOptions(input: "2 7", output: "0 1", name: "Sample", sample: true, score: 10)
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "POST")
        #expect(sent.path == "/x/api/v3/questions/q1/testcases")
        #expect(sent.body["input"] as? String == "2 7")
        #expect(sent.body["output"] as? String == "0 1")
        #expect(sent.body["name"] as? String == "Sample")
        // The schema types `sample` as an integer.
        #expect(sent.body["sample"] as? Int == 1)
        #expect(sent.body["score"] as? Int == 10)
        // Unset fields stay out of the body rather than being sent as null.
        #expect(sent.body["explanation"] == nil)
        #expect(sent.body["qid"] == nil)
    }

    @Test
    func `updateTestcase puts to the testcase path`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.updateTestcase(
            questionID: "q1",
            testcaseID: "tc1",
            options: QuestionTestcaseOptions(explanation: "Indices of the pair", score: 20)
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "PUT")
        #expect(sent.path == "/x/api/v3/questions/q1/testcases/tc1")
        #expect(sent.body["explanation"] as? String == "Indices of the pair")
        #expect(sent.body["score"] as? Int == 20)
    }

    @Test
    func `updateInterview puts the typed interview fields`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.updateInterview(
            id: "i1",
            options: InterviewUpdateOptions(
                title: "Backend Pairing",
                from: "2026-07-10T09:00:00Z",
                to: "2026-07-10T10:00:00Z",
                candidate: InterviewCandidate(email: "ada@example.com"),
                interviewers: ["ian@example.com"],
                notes: "Discuss APIs"
            )
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "PUT")
        #expect(sent.path == "/x/api/v3/interviews/i1")
        #expect(sent.body["title"] as? String == "Backend Pairing")
        #expect(sent.body["from"] as? String == "2026-07-10T09:00:00Z")
        #expect(sent.body["to"] as? String == "2026-07-10T10:00:00Z")
        #expect((sent.body["candidate"] as? [String: Any])?["email"] as? String == "ada@example.com")
        #expect(sent.body["interviewers"] as? [String] == ["ian@example.com"])
        #expect(sent.body["replace_interviewers"] as? Bool == true)
        #expect(sent.body["notes"] as? String == "Discuss APIs")
    }

    @Test
    func `scheduleInterview posts the documented create body`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.scheduleInterview(
            title: "Backend Pairing",
            from: Date(timeIntervalSince1970: 1_780_000_000),
            to: Date(timeIntervalSince1970: 1_780_003_600),
            candidate: InterviewCandidate(email: "ada@example.com", name: "Ada Lovelace"),
            interviewers: ["ian@example.com", " "],
            notes: "Discuss APIs"
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "POST")
        #expect(sent.path == "/x/api/v3/interviews")
        #expect(sent.body["title"] as? String == "Backend Pairing")
        #expect(sent.body["from"] as? String != nil)
        // A scheduled interview can now carry its end time and its interviewers.
        #expect(sent.body["to"] as? String != nil)
        #expect(sent.body["interviewers"] as? [String] == ["ian@example.com"])
        #expect((sent.body["candidate"] as? [String: Any])?["name"] as? String == "Ada Lovelace")
    }

    @Test
    func `createQuickPad posts only the documented fields`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.createQuickPad(title: "Pairing pad")

        let sent = try sentRequest(recorder)
        #expect(sent.method == "POST")
        #expect(sent.path == "/x/api/v3/interviews")
        // `quickpad` is not a property of the interview create schema.
        #expect(sent.body as? [String: String] == ["title": "Pairing pad"])
    }

    @Test
    func `createInterviewTemplate posts the typed template body`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.createInterviewTemplate(
            options: InterviewTemplateWriteOptions(
                name: "Backend Template",
                title: "Backend Pairing",
                description: "Live interview",
                questions: ["q1"],
                tags: ["backend"],
                metadata: ["source": .string("api")]
            )
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "POST")
        #expect(sent.path == "/x/api/v3/interview_templates")
        #expect(sent.body["name"] as? String == "Backend Template")
        #expect(sent.body["title"] as? String == "Backend Pairing")
        #expect(sent.body["description"] as? String == "Live interview")
        #expect(sent.body["questions"] as? [String] == ["q1"])
        #expect(sent.body["tags"] as? [String] == ["backend"])
        #expect((sent.body["metadata"] as? [String: Any])?["source"] as? String == "api")
    }

    @Test
    func `updateInterviewTemplate puts to the template id path`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.updateInterviewTemplate(
            id: 101,
            options: InterviewTemplateWriteOptions(name: "Renamed Template", description: "")
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "PUT")
        #expect(sent.path == "/x/api/v3/interview_templates/101")
        #expect(sent.body["name"] as? String == "Renamed Template")
        // An explicit empty description is a clear, so it must survive onto the wire.
        #expect(sent.body["description"] as? String == "")
        #expect(sent.body["title"] == nil)
    }

    @Test
    func `the documented 204 writes succeed on an empty body`() async throws {
        // Every one of these used to decode a record from the empty response and report
        // `HackerRankError.decode` after the mutation had already been applied.
        let (client, recorder) = RecordedClient.make { _ in (204, Data()) }
        try await client.archiveTest(testID: "t1")
        try await client.deleteTest(testID: "t1")
        try await client.lockUser(id: "u1")
        try await client.removeTeamMember(teamID: "tm1", userID: "u1")

        #expect(recorder.requests.map { $0.httpMethod ?? "" } == ["POST", "DELETE", "DELETE", "DELETE"])
        #expect(recorder.requests.compactMap(\.url?.path) == [
            "/x/api/v3/tests/t1/archive",
            "/x/api/v3/tests/t1",
            "/x/api/v3/users/u1",
            "/x/api/v3/teams/tm1/users/u1"
        ])
    }
}
