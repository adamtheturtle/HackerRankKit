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
            stubs: [QuestionCodeStub(language: "swift", code: "func solve() {}")]
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "PUT")
        #expect(sent.path == "/x/api/v3/questions/q1/custom_codestubs")
        let stubs = try #require(sent.body["custom_codestubs"] as? [[String: Any]])
        #expect(stubs.first?["language"] as? String == "swift")
        #expect(stubs.first?["code"] as? String == "func solve() {}")
    }

    @Test
    func `generateCodeStubs puts the signature metadata`() async throws {
        let (client, recorder) = recordedClient()
        _ = try await client.generateCodeStubs(
            questionID: "q1",
            options: CodeStubGenerationOptions(
                functionName: "twoSum",
                returnType: "[Int]",
                parameters: [CodeStubParameter(name: "nums", type: "[Int]")],
                languages: ["swift"]
            )
        )

        let sent = try sentRequest(recorder)
        #expect(sent.method == "PUT")
        #expect(sent.path == "/x/api/v3/questions/q1/generate")
        #expect(sent.body["function_name"] as? String == "twoSum")
        #expect(sent.body["return_type"] as? String == "[Int]")
        #expect(sent.body["languages"] as? [String] == ["swift"])
        #expect((sent.body["parameters"] as? [[String: Any]])?.first?["type"] as? String == "[Int]")
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
        #expect(sent.body["sample"] as? Bool == true)
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
                candidate: "ada@example.com",
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
        #expect(sent.body["candidate"] as? String == "ada@example.com")
        #expect(sent.body["interviewers"] as? [String] == ["ian@example.com"])
        #expect(sent.body["notes"] as? String == "Discuss APIs")
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
}
