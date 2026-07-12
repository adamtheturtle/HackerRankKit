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
    func `test inviters returns a paged inviter list`() async throws {
        let page = try await client.testInviters(testID: "t1")
        #expect(page.items.map(\.id) == ["u1", "u2", "u-missing-email"])
        #expect(page.items.first?.email == "rhea@example.com")
        #expect(page.items.last?.email == "")
        #expect(page.next == nil)
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
    func `single candidate detail decodes as one object`() async throws {
        let candidate = try await client.candidate(testID: "t1", candidateID: "c1")
        #expect(candidate.id == "c1")
        #expect(candidate.fullName == "Ada Lovelace")
        #expect(candidate.tags == ["shortlist", "single-read"])
        #expect(candidate.editorPasteCount == 1)
    }

    @Test
    func `write flows return their echoed record`() async throws {
        let created = try await client.createTest(name: "New Screen")
        #expect(created.id == "t-created")
        let invited = try await client.inviteCandidate(testID: "t1", email: "x@example.com")
        #expect(invited.email == "invited@example.com")
    }

    @Test
    func `question write flows return their echoed record`() async throws {
        let created = try await client.createQuestion(name: "New Question", type: "code")
        #expect(created.id == "q-written")
        let updated = try await client.updateQuestion(questionID: "q1", name: "Renamed Question")
        #expect(updated.name == "New Question")
        let deleted = try await client.deleteQuestion(questionID: "q1")
        #expect(deleted.type == "code")
    }

    @Test
    func `createUser with team ids returns the echoed record`() async throws {
        let created = try await client.createUser(
            email: "new@example.com", firstName: "New", role: "recruiter", teamIDs: ["tm1"]
        )
        #expect(created.id == "u-created")
    }

    @Test
    func `currentUser returns the demo identity`() async throws {
        let me = try await client.currentUser()
        #expect(me.email == "demo@example.com")
    }

    @Test
    func `core management gaps are routed by the mock server`() async throws {
        let archived = try await client.archiveTest(testID: "t1")
        #expect(archived.id == "t-created")

        let updatedCandidate = try await client.updateCandidate(
            testID: "t1",
            candidateID: "c1",
            options: CandidateUpdateOptions(fullName: "Ada Lovelace")
        )
        #expect(updatedCandidate.id == "c-invited")

        let pdf = try await client.candidateReportPDF(testID: "t1", candidateID: "c1")
        #expect(pdf.pdfURL == "https://www.hackerrank.com/x/candidates/c1/report.pdf")

        let user = try await client.user(id: "u1")
        #expect(user.email == "rhea@example.com")
        let team = try await client.team(id: "tm1")
        #expect(team.name == "Backend Hiring")
        let membership = try await client.addTeamMember(teamID: "tm1", userID: "u1", license: "recruiter")
        #expect(membership.email == "rhea@example.com")
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
