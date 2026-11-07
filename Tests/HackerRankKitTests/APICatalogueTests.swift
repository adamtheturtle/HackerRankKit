import Foundation
@testable import HackerRankKit
import HackerRankKitMock
import Testing

@Suite("Complete API contract")
struct APICatalogueTests {
    @Test
    func `every documented operation has a runnable transport and mock route`() async throws {
        let catalogue = try HackerRankClient.apiCatalogue()
        #expect(catalogue.operations.count == 76)
        #expect(Set(catalogue.operations.map(\.id)).count == 76)
        let client = HackerRankClient.mock()
        for operation in catalogue.operations {
            var path: [String: String] = [:]
            var query: [URLQueryItem] = []
            for parameter in operation.parameters {
                if parameter.location == "path" { path[parameter.name] = "1" }
                if parameter.location == "query" && parameter.required {
                    query.append(URLQueryItem(name: parameter.name, value: "1"))
                }
            }
            if operation.id == "api_get_report_pdf" { query.append(URLQueryItem(name: "format", value: "url")) }
            let result = try await client.executeAPI(
                operation.id, pathParameters: path, query: query,
                body: operation.bodyRequired ? .object([:]) : nil, scimToken: "synthetic-provisioning-token"
            )
            #expect((200 ..< 300).contains(result.status), "\(operation.id) should have a runnable route")
            #expect(catalogue.inputSchema(for: operation) != .null)
        }
    }

    @Test
    func `generic execution preserves pending and empty responses`() async throws {
        let (client, _) = RecordedClient.make(responseHeaders: ["Retry-After": "180"]) { url in
            url.path.hasSuffix("artifacts") ? (202, Data(#"{"message":"Pending"}"#.utf8)) : (204, Data())
        }
        let pending = try await client.executeAPI("api_get_interview_artifacts", pathParameters: ["interview_id": "1"])
        #expect(pending.status == 202)
        #expect(pending.headers.first(where: { $0.key.lowercased() == "retry-after" })?.value == "180")
        let empty = try await client.executeAPI("api_lock_user", pathParameters: ["id": "1"])
        #expect(empty.status == 204)
        #expect(empty.data == nil)
    }

    @Test
    func `SCIM requires and sends its own token`() async throws {
        let (client, recorder) = RecordedClient.make(additionalBearerTokens: ["provisioning-only"])
        do {
            _ = try await client.executeAPI("api_scim_list_users")
            Issue.record("Expected missing provisioning token")
        } catch let error as HackerRankError {
            guard case .http(0, _) = error else { throw error }
        }
        #expect(recorder.requests.isEmpty)
        _ = try await client.executeAPI("api_scim_list_users", scimToken: "provisioning-only")
        #expect(recorder.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer provisioning-only")
        #expect(recorder.requests.last?.url?.host == "services.hackerrank.com")
    }

    @Test
    func `query input preserves CSV arrays booleans and escaped identifiers`() throws {
        let inputs = try HackerRankAPIInputs(value: .object([
            "path": .object(["id": .string("a/b+")]),
            "query": .object(["note_ids": .array([.int(1), .int(2)]), "include_total": .bool(false)])
        ]))
        #expect(inputs.pathParameters == ["id": "a/b+"])
        #expect(inputs.query.contains(URLQueryItem(name: "note_ids", value: "1,2")))
        #expect(inputs.query.contains(URLQueryItem(name: "include_total", value: "false")))
    }
}
