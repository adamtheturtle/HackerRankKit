//
//  MockServerTests.swift
//  HackerRankKitTests
//

import Foundation
import HackerRankKit
import HackerRankKitMock
import Testing

/// End-to-end coverage of the client against the in-process mock server. Each test uses
/// a client keyed by a unique API key, so the suite can run in parallel.
@Suite("Mock server end-to-end")
struct MockServerTests {
    private let client = HackerRankClient.mock(key: "test-\(UUID().uuidString)")

    @Test
    func `testsPage returns the seeded tests and a next cursor`() async throws {
        let page = try await client.testsPage()
        #expect(page.items.count == 3)
        #expect(page.items.contains { $0.id == "t1" })
        #expect(page.next != nil)
    }

    @Test
    func `testsPage follows the next cursor to page two`() async throws {
        let first = try await client.testsPage()
        let next = try #require(first.next)
        let second = try await client.testsPage(after: next)
        #expect(second.items.map(\.id) == ["t4", "t5"])
        #expect(second.next == nil)
    }

    @Test
    func `single test detail exposes the sensitive fields`() async throws {
        let detail = try await client.test(id: "t1")
        #expect(detail.accessPassword == "demo-master-pw")
        #expect(detail.hasScoring)
    }

    @Test
    func `interview detail and transcript decode`() async throws {
        let detail = try await client.interview(id: "i1")
        #expect(detail.candidate?.displayName == "Ada Lovelace")
        let transcript = try await client.interviewTranscript(id: "i1")
        #expect(transcript.messages.count == 3)
    }

    @Test
    func `candidate search narrows server-side`() async throws {
        let all = try await client.searchCandidates(testID: "t1", query: "")
        let ada = try await client.searchCandidates(testID: "t1", query: "ada")
        #expect(all.items.count == 2)
        #expect(ada.items.map(\.id) == ["c1"])
    }

    @Test
    func `write flows return their echoed record`() async throws {
        let created = try await client.createTest(name: "New Screen")
        #expect(created.id == "t-created")
        let invited = try await client.inviteCandidate(testID: "t1", email: "x@example.com")
        #expect(invited.email == "invited@example.com")
    }

    @Test
    func `currentUser returns the demo identity`() async throws {
        let me = try await client.currentUser()
        #expect(me.email == "demo@example.com")
    }

    @Test
    func `an unauthorized client surfaces isUnauthorized`() async throws {
        let client = HackerRankClient.mock(unauthorized: true, key: "bad-\(UUID().uuidString)")
        await #expect {
            try await client.testsPage()
        } throws: { error in
            (error as? HackerRankError)?.isUnauthorized == true
        }
    }
}
