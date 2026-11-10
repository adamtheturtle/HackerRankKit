import Foundation
@testable import HackerRankKit
import HackerRankKitMock
import Testing

@Suite("Question read and write contracts")
struct QuestionContractTests {
    private func encoded(_ value: some Encodable) throws -> Data {
        try HackerRankClient.makeEncoder().encode(value)
    }

    private func current(answer: HackerRankJSONValue = .string("0")) -> [String: HackerRankJSONValue] {
        [
            "id": .string("q1"), "type": .string("fullstack"), "name": .string("Current"),
            "problem_statement": .string("Keep statement"), "recommended_duration": .int(0),
            "internal_notes": .string(" Keep notes.\n"), "languages": .array([.string("python3")]),
            "tags": .array([.string("tag")]), "options": .array([.string("choice")]), "answer": answer,
            "environment_id": .int(112), "custom_system_prompt": .string("Keep prompt"),
            "fullstack_project_details": .object(["configuration": .object(["menu": .object([:])])])
        ]
    }

    @Test(arguments: [QuestionAnswer.text("0"), .text("  answer\n"), .text(""), .option(0), .options([1, 2])])
    func answersRoundTrip(_ answer: QuestionAnswer) throws {
        let bytes = try encoded(answer)
        #expect(try HackerRankClient.makeDecoder().decode(QuestionAnswer.self, from: bytes) == answer)
        let detail = try HackerRankClient.makeDecoder().decode(QuestionDetail.self, from: encoded(
            HackerRankJSONValue.object(current(answer: try HackerRankClient.makeDecoder().decode(
                HackerRankJSONValue.self, from: bytes
            )))
        ))
        #expect(detail.answer == answer)
        if case .text = answer { #expect(answer.indices.isEmpty) }
        let created = CreateQuestionRequest(
            name: "Question", type: "mcq", problemStatement: "Choose", recommendedDuration: 1,
            options: QuestionWriteOptions(answer: answer)
        )
        let updated = UpdateQuestionRequest(name: nil, type: nil, options: QuestionWriteOptions(answer: answer))
        for body in [try encoded(created), try encoded(updated)] {
            guard case let .object(fields) = try HackerRankClient.makeDecoder().decode(
                HackerRankJSONValue.self,
                from: body
            )
            else { Issue.record("Expected question body"); return }
            #expect(try encoded(fields["answer"]) == encoded(answer))
        }
    }

    @Test(arguments: [HackerRankJSONValue.null, .object([:]), .double(1.5), .array([.string("0")])])
    func malformedAnswersAreNotStrings(_ value: HackerRankJSONValue) throws {
        #expect(throws: DecodingError.self) {
            try HackerRankClient.makeDecoder().decode(QuestionAnswer.self, from: encoded(value))
        }
        let absent = QuestionDetail(question: Question(id: "q1", type: "mcq", name: "Question"))
        #expect(absent.answer == nil)
    }

    @Test
    func knownTypesKeepUnknownResponses() throws {
        #expect(Set(QuestionType.allCases.map(\.rawValue)) == [
            "code", "approx", "mcq", "multiple_mcq", "whiteboard", "file_upload", "textAns", "fullstack"
        ])
        for type in QuestionType.allCases {
            let question = Question(id: "q1", type: type.rawValue, name: "Question")
            #expect(question.knownType == type)
            #expect(question.supportsCustomSystemPrompt == (type == .fullstack))
        }
        let unknown = try HackerRankClient.makeDecoder().decode(Question.self, from: Data(
            #"{"id":"q1","type":"future_type","name":"Future"}"#.utf8
        ))
        #expect(unknown.type == "future_type")
        #expect(unknown.knownType == nil)
        #expect(!unknown.supportsCustomSystemPrompt)
    }

    @Test(arguments: ["code", "whiteboard", "mcq"])
    func unsupportedPromptsNeverWrite(_ type: String) async throws {
        let (client, recorder) = RecordedClient.make()
        await #expect(throws: EncodingError.self) {
            try await client.createQuestion(
                name: "Question", type: type, problemStatement: "Choose", recommendedDuration: 1,
                options: QuestionWriteOptions(customSystemPrompt: "")
            )
        }
        await #expect(throws: EncodingError.self) {
            try await client.executeAPI("api_update_question", pathParameters: ["question_id": "q1"], body: .object([
                "type": .string(type), "custom_system_prompt": .string("")
            ]))
        }
        #expect(recorder.requests.isEmpty)
    }

    @Test(arguments: ["fullstack", "future_type"])
    func supportedAndFuturePromptsKeepExactText(_ type: String) async throws {
        let response = Data(#"{"id":"q1"}"#.utf8)
        let (client, recorder) = RecordedClient.make { _ in (200, response) }
        _ = try await client.createQuestion(
            name: "Question", type: type, problemStatement: "Choose", recommendedDuration: 1,
            options: QuestionWriteOptions(customSystemPrompt: "  Hints.\n")
        )
        _ = try await client.executeAPI("api_update_question", pathParameters: ["question_id": "q1"], body: .object([
            "type": .string(type), "custom_system_prompt": .string("")
        ]))
        #expect(recorder.requests.map(\.httpMethod) == ["POST", "PUT"])
    }

    @Test(arguments: [HackerRankJSONValue.int(1), .string(String(repeating: "x", count: 15001))])
    func malformedGenericPromptIsLocal(_ value: HackerRankJSONValue) async throws {
        let (client, recorder) = RecordedClient.make()
        await #expect(throws: EncodingError.self) {
            try await client.executeAPI("api_create_question", body: .object(["custom_system_prompt": value]))
        }
        #expect(recorder.requests.isEmpty)
    }

    @Test(arguments: [HackerRankJSONValue.string("0"), .int(0), .array([.int(1), .int(2)]), .null])
    func metadataPreservesRequiredFields(_ answer: HackerRankJSONValue) async throws {
        let snapshot = try encoded(HackerRankJSONValue.object(current(answer: answer)))
        let (client, recorder) = RecordedClient.make { url in
            url.absoluteString.hasSuffix("/") ? (204, Data()) : (200, snapshot)
        }
        let result = try await client.updateQuestionMetadata(questionID: "q1", changes: .init(name: "Renamed"))
        #expect(result == nil)
        #expect(recorder.requests.map(\.httpMethod) == ["GET", "PUT"])
        let expected: HackerRankJSONValue = .object([
            "name": .string("Renamed"), "type": .string("fullstack"),
            "internal_notes": .string(" Keep notes.\n"), "languages": .array([.string("python3")]),
            "problem_statement": .string("Keep statement"), "recommended_duration": .int(0),
            "tags": .array([.string("tag")]), "options": .array([.string("choice")]),
            "answer": answer == .null ? .array([]) : answer
        ])
        #expect(try HackerRankClient.makeDecoder().decode(
            HackerRankJSONValue.self,
            from: #require(recorder.bodies.last)
        ) == expected)
    }

    @Test
    func explicitChangesCanSupplyMissingFieldsAndClearValues() async throws {
        let snapshot = Data(#"{"id":"q1","name":"Current","type":"fullstack"}"#.utf8)
        let (client, recorder) = RecordedClient.make { url in
            url.absoluteString.hasSuffix("/") ? (200, Data(#"{"data":{"id":"q1","name":"Renamed"}}"#.utf8)) : (
                200,
                snapshot
            )
        }
        let result = try await client.updateQuestionMetadata(questionID: "q1", changes: .init(
            name: "Renamed", internalNotes: "", languages: [], problemStatement: "", recommendedDuration: 0,
            tags: [], options: [], answer: .text(""), customSystemPrompt: ""
        ))
        #expect(result?.name == "Renamed")
        let payload = try HackerRankClient.makeDecoder().decode(
            HackerRankJSONValue.self,
            from: #require(recorder.bodies.last)
        )
        #expect(payload == .object([
            "name": .string("Renamed"), "type": .string("fullstack"), "internal_notes": .string(""),
            "languages": .array([]), "problem_statement": .string(""), "recommended_duration": .int(0),
            "tags": .array([]), "options": .array([]), "answer": .string(""), "custom_system_prompt": .string("")
        ]))
    }

    @Test(arguments: ["problem_statement", "recommended_duration", "answer", "options", "internal_notes", "type"])
    func incompleteOrMalformedReadsNeverWrite(_ field: String) async throws {
        var fields = current()
        if ["problem_statement", "recommended_duration"].contains(field) {
            fields.removeValue(forKey: field)
        } else {
            fields[field] = .object([:])
        }
        let snapshot = try encoded(HackerRankJSONValue.object(fields))
        let (client, recorder) = RecordedClient.make { _ in (200, snapshot) }
        await #expect(throws: (any Error).self) {
            try await client.updateQuestionMetadata(questionID: "q1", changes: .init(name: "Renamed"))
        }
        #expect(recorder.requests.map(\.httpMethod) == ["GET"])
    }

    @Test
    func metadataUsesTheFetchedTypeForPrompts() async throws {
        var fields = current()
        fields["type"] = .string("code")
        let snapshot = try encoded(HackerRankJSONValue.object(fields))
        let (client, recorder) = RecordedClient.make { _ in (200, snapshot) }
        await #expect(throws: EncodingError.self) {
            try await client.updateQuestionMetadata(questionID: "q1", changes: .init(customSystemPrompt: ""))
        }
        #expect(recorder.requests.map(\.httpMethod) == ["GET"])
    }

    @Test(arguments: ["direct", "wrapped-null", "null"])
    func metadataAcceptsSparseAndEmptyWriteResults(_ mode: String) async throws {
        let snapshot = try encoded(HackerRankJSONValue.object(current()))
        let result = mode == "direct" ? Data(#"{"id":"q1"}"#.utf8)
            : mode == "wrapped-null" ? Data(#"{"data":null}"#.utf8) : Data("null".utf8)
        let (client, recorder) = RecordedClient.make { url in
            url.absoluteString.hasSuffix("/") ? (200, result) : (200, snapshot)
        }
        let written = try await client.updateQuestionMetadata(questionID: "q1", changes: .init())
        #expect(written?.id == (mode == "direct" ? "q1" : nil))
        #expect(recorder.requests.map(\.httpMethod) == ["GET", "PUT"])
    }

    @Test(arguments: ["fullstack", "code"])
    func selectedTypeControlsPromptValidation(_ type: String) async throws {
        let snapshot = try encoded(HackerRankJSONValue.object(current()))
        let (client, recorder) = RecordedClient.make { url in
            url.absoluteString.hasSuffix("/") ? (204, Data()) : (200, snapshot)
        }
        if type == "code" {
            await #expect(throws: EncodingError.self) {
                try await client.updateQuestionMetadata(
                    questionID: "q1", changes: .init(type: type, customSystemPrompt: "")
                )
            }
            #expect(recorder.requests.map(\.httpMethod) == ["GET"])
        } else {
            _ = try await client.updateQuestionMetadata(
                questionID: "q1", changes: .init(type: type, customSystemPrompt: "")
            )
            let payload = try HackerRankClient.makeDecoder().decode(
                HackerRankJSONValue.self, from: #require(recorder.bodies.last)
            )
            guard case let .object(fields) = payload else { Issue.record("Expected metadata"); return }
            #expect(fields["type"] == .string(type))
            #expect(fields["custom_system_prompt"] == .string(""))
        }
    }

    @Test
    func metadataReadFailuresDoNotWrite() async throws {
        let (client, recorder) = RecordedClient.make { _ in (403, Data()) }
        await #expect(throws: HackerRankError.self) {
            try await client.updateQuestionMetadata(questionID: "q1", changes: .init(name: "New"))
        }
        #expect(recorder.requests.map(\.httpMethod) == ["GET"])
    }

    @Test
    func metadataHelperWorksWithThePublicMock() async throws {
        let result = try await HackerRankClient.mock().updateQuestionMetadata(
            questionID: "q1", changes: .init(name: "Renamed")
        )
        #expect(result?.id != nil)
    }

    @Test
    func canonicalWritesAvoidTheRedirectRoute() async throws {
        let body = Data(#"{"id":"q1"}"#.utf8)
        let (client, recorder) = RecordedClient.make { url in
            url.absoluteString.hasSuffix("/") || url.query != nil ? (200, body) : (307, Data())
        }
        _ = try await client.createQuestion(
            name: "Question",
            type: "code",
            problemStatement: "Choose",
            recommendedDuration: 1
        )
        _ = try await client.updateQuestion(questionID: "a/b+", name: "New")
        _ = try await client.addTestcase(questionID: "a/b+", options: .init(input: "1", output: "2"))
        _ = try await client.executeAPI("api_create_question", body: .object(["type": .string("code")]))
        _ = try await client.executeAPI("api_update_question", pathParameters: ["question_id": "a/b+"],
                                        query: [.init(name: "extra", value: "+ /?offset=1")],
                                        body: .object(["name": .string("New")]))
        #expect(recorder.urls == [
            "https://www.hackerrank.com/x/api/v3/questions/",
            "https://www.hackerrank.com/x/api/v3/questions/a%2Fb%2B/",
            "https://www.hackerrank.com/x/api/v3/questions/a%2Fb%2B/testcases/",
            "https://www.hackerrank.com/x/api/v3/questions/",
            "https://www.hackerrank.com/x/api/v3/questions/a%2Fb%2B/?extra=%2B%20/%3Foffset%3D1"
        ])
        #expect(recorder.requests.map(\.httpMethod) == ["POST", "PUT", "POST", "POST", "PUT"])
        #expect(recorder.requests
            .allSatisfy { $0.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer recorded-") == true })
    }
}
