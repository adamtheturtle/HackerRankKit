//
//  CreateUserRequestTests.swift
//  HackerRankKitTests
//
//  The exact wire shape of the user-create body: the server requires `teams` as an
//  array of `{"id": …}` objects and rejects the create without it, so the encoding
//  is load-bearing in a way the all-optional response echoes are not.
//

import Foundation
@testable import HackerRankKit
import Testing

@Suite("Create-user body encoding")
struct CreateUserRequestTests {
    private func encodeToJSON(_ request: CreateUserRequest) throws -> [String: Any] {
        let data = try HackerRankClient.makeEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data)
        return (object as? [String: Any]) ?? [:]
    }

    @Test
    func `teams encode as an array of id objects`() throws {
        let request = CreateUserRequest(
            email: "new@example.com", firstName: "New", lastName: nil, role: "recruiter",
            teams: [.init(id: "tm1"), .init(id: "tm2")]
        )
        let json = try encodeToJSON(request)
        #expect(json["teams"] as? [[String: String]] == [["id": "tm1"], ["id": "tm2"]])
        #expect(json["firstname"] as? String == "New")
        #expect(json["lastname"] == nil)
    }

    @Test
    func `a create without its required values fails before any request`() async throws {
        // Defaulting these built a body the server rejects after a round trip, so the
        // client refuses it locally instead.
        let (client, recorder) = RecordedClient.make { _ in (200, Data("{}".utf8)) }
        let invalid: [(String, () async throws -> Void)] = [
            ("blank first name", {
                _ = try await client.createUser(
                    email: "new@example.com", firstName: " ", role: "recruiter", teamIDs: ["tm1"]
                )
            }),
            ("blank role", {
                _ = try await client.createUser(
                    email: "new@example.com", firstName: "New", role: "", teamIDs: ["tm1"]
                )
            }),
            ("no teams", {
                _ = try await client.createUser(
                    email: "new@example.com", firstName: "New", role: "recruiter", teamIDs: [" "]
                )
            })
        ]

        for (name, create) in invalid {
            do {
                try await create()
                Issue.record("\(name) should be rejected")
            } catch let HackerRankError.http(status, _) {
                #expect(status == 0)
            }
        }
        #expect(recorder.requests.isEmpty)
    }
}
