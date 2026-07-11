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
    func `nil teams are omitted from the body`() throws {
        let request = CreateUserRequest(
            email: "new@example.com", firstName: nil, lastName: nil, role: nil, teams: nil
        )
        let json = try encodeToJSON(request)
        #expect(json["teams"] == nil)
        #expect(json["email"] as? String == "new@example.com")
    }
}
