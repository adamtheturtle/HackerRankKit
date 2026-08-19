//
//  AllUsersOffsetTests.swift
//  HackerRankKitTests
//
//  `allUsers` fans its remaining pages out by offset. The server offsets by the `limit`
//  the client asked for, so the offsets have to come from the requested page size — not
//  from how many rows survived decoding, which the lenient page decoder can shorten.
//

import Foundation
@testable import HackerRankKit
import Testing

@Suite("allUsers offset fan-out")
struct AllUsersOffsetTests {
    /// A users page of `count` rows starting at `offset`, reporting `total`. When
    /// `dropOneRow` is set the first row is malformed (no `id`), so `HackerRankPage`'s
    /// lenient decoder discards it exactly as it would on a live account.
    private nonisolated static func page(offset: Int, count: Int, total: Int, dropOneRow: Bool = false) -> Data {
        let rows = (offset ..< (offset + count)).map { index in
            dropOneRow && index == offset
                ? #"{"email":"broken@example.com"}"#
                : #"{"id":"u\#(index)","email":"u\#(index)@example.com"}"#
        }
        return Data(#"{"data":[\#(rows.joined(separator: ","))],"next":null,"total":\#(total)}"#.utf8)
    }

    @Test
    func `a dropped row does not shift the remaining offsets`() async throws {
        let total = 250
        let (client, recorder) = RecordedClient.make { url in
            let offset = Int(
                URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "offset" }?.value ?? "0"
            ) ?? 0
            let count = min(100, total - offset)
            // The first page carries one malformed record, so it decodes to 99 users.
            return (200, Self.page(offset: offset, count: count, total: total, dropOneRow: offset == 0))
        }

        let users = try await client.allUsers()

        let offsets = recorder.urls
            .compactMap { url in URLComponents(string: url)?.queryItems?.first { $0.name == "offset" }?.value }
            .compactMap(Int.init)
            .sorted()
        #expect(offsets == [0, 100, 200])
        // 249 rather than 250: the malformed record is genuinely gone, and no id is
        // fetched twice to paper over it.
        #expect(users.count == 249)
        #expect(Set(users.map(\.id)).count == users.count)
    }

    @Test
    func `maxUsers bounds what is returned, not just what is requested`() async throws {
        // Pages arrive whole, so the last one fetched overshoots the bound; the result has
        // to be truncated rather than handed back long.
        let (client, _) = RecordedClient.make { url in
            let offset = Int(
                URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "offset" }?.value ?? "0"
            ) ?? 0
            return (200, Self.page(offset: offset, count: 100, total: 500))
        }

        #expect(try await client.allUsers(maxUsers: 1).count == 1)
        #expect(try await client.allUsers(maxUsers: 150).count == 150)
        #expect(try await client.allUsers(maxUsers: 0).isEmpty)
    }

    @Test
    func `a first page of only malformed rows still fans out`() async throws {
        // Every row on page one drifts, so it decodes to nothing. The envelope still
        // reports 200 users, and the later offsets hold valid ones.
        let (client, recorder) = RecordedClient.make { url in
            let offset = Int(
                URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "offset" }?.value ?? "0"
            ) ?? 0
            guard offset > 0 else {
                let broken = Array(repeating: #"{"email":"broken@example.com"}"#, count: 100)
                return (200, Data(#"{"data":[\#(broken.joined(separator: ","))],"total":200}"#.utf8))
            }

            return (200, Self.page(offset: offset, count: 100, total: 200))
        }

        let users = try await client.allUsers()

        #expect(users.count == 100)
        #expect(recorder.urls.count == 2)
    }

    @Test
    func `a collection that fits in one page makes no follow-up request`() async throws {
        let (client, recorder) = RecordedClient.make { _ in
            (200, Self.page(offset: 0, count: 40, total: 40))
        }

        let users = try await client.allUsers()

        #expect(users.count == 40)
        #expect(recorder.urls.count == 1)
    }
}
