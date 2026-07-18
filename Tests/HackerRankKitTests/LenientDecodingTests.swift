//
//  LenientDecodingTests.swift
//  HackerRankKitTests
//
//  A single malformed row in a list response must cost that row and nothing else. A
//  populated directory reading as empty is indistinguishable, to a caller, from a real
//  empty directory — there is no error and no log line to notice.
//

import Foundation
@testable import HackerRankKit
import Testing

@Suite("Lenient list decoding")
struct LenientDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test
    func `a SCIM list keeps its good rows when one element fails to decode`() throws {
        // `id` is `String?` on `SCIMUser`, so the numeric first row cannot decode.
        let response = try decode(SCIMListResponse<SCIMUser>.self, """
        {"Resources":[{"id":123,"userName":"a@b.c"},{"id":"ok","userName":"d@e.f"}],"totalResults":2}
        """)

        #expect(response.resources.map(\.userName) == ["d@e.f"])
        #expect(response.totalResults == 2)
    }

    @Test
    func `a SCIM group list keeps its good rows when one element fails to decode`() throws {
        // `SCIMGroup` tolerates a wrong-typed *field*, so the malformed row here is a
        // scalar where the schema promises an object — a whole element that cannot decode.
        let response = try decode(SCIMListResponse<SCIMGroup>.self, """
        {"Resources":["oops",{"id":"g1","displayName":"Backend Hiring"}]}
        """)

        #expect(response.resources.map(\.displayName) == ["Backend Hiring"])
    }

    @Test
    func `a SCIM list under the data key is decoded leniently too`() throws {
        let response = try decode(SCIMListResponse<SCIMUser>.self, """
        {"data":[{"id":123,"userName":"a@b.c"},{"id":"ok","userName":"d@e.f"}]}
        """)

        #expect(response.resources.map(\.userName) == ["d@e.f"])
    }

    @Test
    func `a SCIM list with no recognisable array decodes as empty rather than failing`() throws {
        let response = try decode(SCIMListResponse<SCIMUser>.self, #"{"totalResults":0}"#)

        #expect(response.resources.isEmpty)
    }
}
