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
    func `seeded tests carry the documented configuration fields`() async throws {
        let page = try await client.testsPage()
        let test = try #require(page.items.first { $0.id == "t1" })
        #expect(test.startTime == "2026-05-01T09:00:00Z")
        #expect(test.endTime == "2026-06-01T09:00:00Z")
        #expect(test.roleIDs == ["Backend Engineer"])
        #expect(test.experience == ["Senior"])
        #expect(test.candidateDetails == ["full_name", "university"])
        #expect(test.testAdmins == ["u1", "u2"])
        #expect(test.ideConfig == "default")
        #expect(test.enableAdvancedProctoring == true)
        #expect(test.enablePhotoIdentification == true)
        // The fixture serves `sections` in the documented object shape.
        #expect(test.sections?.map(\.displayName) == ["Coding", "Multiple Choice"])
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
        // The invite, integrity, and per-question fields the detail endpoint documents.
        #expect(candidate.user == "u1")
        #expect(candidate.integritySummary == "No integrity signals detected.")
        #expect(candidate.inviteEmailDone == true)
        #expect(candidate.inviteValid == true)
        #expect(candidate.invitedOn == "2026-05-01T09:00:00Z")
        #expect(candidate.inviteValidTo == "2026-05-08T09:00:00Z")
        #expect(candidate.inviteLink?.hasPrefix("https://") == true)
        #expect(candidate.inviteMetadata?["source"] == .string("careers-site"))
        #expect(candidate.evaluatorEmail == "ian@example.com")
        #expect(candidate.testResultURL == "https://example.com/webhook")
        #expect(candidate.acceptResultUpdates == true)
        #expect(candidate.authenticatedReportURL?.hasSuffix("auth=1") == true)
        #expect(candidate.scoresTagsSplit?["backend"] == .int(60))
        #expect(candidate.scoresSkillsSplit?["APIs"] == .int(32))
        #expect(candidate.addedTime == "30")
        #expect(candidate.unclaimedAddedTime == 10)
        #expect(candidate.comments?["summary"] == .string("Strong candidate."))
        #expect(candidate.performanceSummary?.isEmpty == false)
        #expect(candidate.ipAddress == "203.0.113.7")
        #expect(candidate.attemptEvents?.count == 1)
        #expect(candidate.questionScores?.map(\.id) == ["q1", "q2"])
        #expect(candidate.questionScores?.first?.name == "Two Sum")
        #expect(candidate.candidateDetails?.first?.title == "University")
        #expect(candidate.proctorImages?.count == 1)
    }

    @Test
    func `write flows return their echoed record`() async throws {
        let created = try await client.createTest(
            name: "New Screen", duration: 60, roleIDs: ["r1"], experience: ["Senior"]
        )
        #expect(created.id == "t-created")
        let invited = try await client.inviteCandidate(testID: "t1", email: "x@example.com")
        #expect(invited.email == "invited@example.com")
    }

    @Test
    func `question write flows return their echoed record`() async throws {
        let created = try await client.createQuestion(
            name: "New Question", type: "code", problemStatement: "Return two indices.", recommendedDuration: 20
        )
        #expect(created.id == "q-written")
        let updated = try await client.updateQuestion(questionID: "q1", name: "Renamed Question")
        #expect(updated.name == "New Question")
    }

    @Test
    func `the single-question read carries the whole resource`() async throws {
        let detail = try await client.question(id: "q3")
        // The base resource comes back from the same response, so a detail refresh can
        // replace a stale list row instead of only annotating one.
        #expect(detail.question.id == "q3")
        #expect(detail.question.name == "SQL Joins")
        #expect(detail.question.type == "mcq")
        #expect(detail.question.owner == "u1")
        #expect(detail.options.count == 4)
        // The answer is a one-based option index, not the option's text.
        #expect(detail.answer == .option(2))
        #expect(detail.answer?.indices == [2])
        #expect(detail.hasContent)
    }

    @Test
    func `question codestub and testcase writes return an operation ack`() async throws {
        let stubs = try await client.updateCustomCodeStubs(
            questionID: "q1", stubs: [QuestionCodeStub(language: "swift", body: "func solve() {}")]
        )
        #expect(stubs.status == "ok")

        // Generation answers with the templates it produced, not a status acknowledgement.
        let generated = try await client.generateCodeStubs(
            questionID: "q1",
            options: CodeStubGenerationOptions(
                type: "code", functionName: "twoSum", allowedLanguages: ["c", "clojure"]
            )
        )
        #expect(generated.functionName == "twoSum")
        #expect(generated.templates.map(\.language) == ["c", "clojure"])
        #expect(generated.templates.first?.head?.isEmpty == false)
        #expect(generated.templates.first?.body?.isEmpty == false)
        #expect(generated.templates.first?.tail?.isEmpty == false)

        let added = try await client.addTestcase(
            questionID: "q1",
            options: QuestionTestcaseOptions(input: "input", output: "output", name: "Sample", score: 10)
        )
        #expect(added.id == "qop-1")
        #expect(added.message == "Question operation completed")

        let updated = try await client.updateTestcase(
            questionID: "q1", testcaseID: "tc1", options: QuestionTestcaseOptions(score: 20)
        )
        #expect(updated.status == "ok")

        let deleted = try await client.deleteTestcase(questionID: "q1", testcaseID: "tc1")
        #expect(deleted.id == "qop-1")
    }

    @Test
    func `interview template writes return the echoed template`() async throws {
        let created = try await client.createInterviewTemplate(name: "Backend Template")
        #expect(created.id == 101)

        let updated = try await client.updateInterviewTemplate(
            id: 101, options: InterviewTemplateUpdateOptions(name: "Renamed Template")
        )
        #expect(updated.name == "Backend Pairing")
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
        // The documented 204 endpoints answer with an empty body: returning normally is
        // the whole result, and used to be reported as a decode failure instead.
        try await client.archiveTest(testID: "t1")
        try await client.deleteTest(testID: "t5")
        try await client.lockUser(id: "u1")
        try await client.removeTeamMember(teamID: "tm1", userID: "u2")

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
        #expect(user.phone == "+44 20 7946 0000")
        #expect(user.timezone == "Europe/London")
        #expect(user.questionsPermission == 2)
        #expect(user.testsPermission == 2)
        #expect(user.interviewsPermission == 1)
        #expect(user.candidatesPermission == 2)
        #expect(user.sharedQuestionsPermission == 1)
        #expect(user.sharedTestsPermission == 1)
        #expect(user.sharedInterviewsPermission == 0)
        #expect(user.sharedCandidatesPermission == 1)
        let team = try await client.team(id: "tm1")
        #expect(team.name == "Backend Hiring")
        #expect(team.recruiterCap == 5)
        #expect(team.developerCap == 20)
        #expect(team.inviteAs == "Example Recruiting")
        let membership = try await client.addTeamMember(teamID: "tm1", userID: "u1", license: "recruiter")
        // The membership response is the pair of ids, and nothing else.
        #expect(membership.team == "tm1")
        #expect(membership.user == "u1")
    }

    @Test
    func `scim provisioning endpoints are routed by the mock server`() async throws {
        let users = try await client.scimUsers()
        #expect(users.resources.first?.userName == "rhea@example.com")
        let user = try await client.scimUser(id: "scim-u1")
        #expect(user.id == "scim-u1")
        let createdUser = try await client.createSCIMUser(body: SCIMUserWriteRequest(userName: "rhea@example.com"))
        #expect(createdUser.userName == "rhea@example.com")
        try await client.lockSCIMUser(id: "scim-u1")

        let groups = try await client.scimGroups()
        #expect(groups.resources.first?.displayName == "Backend Hiring")
        let group = try await client.scimGroup(id: "scim-g1")
        #expect(group.id == "scim-g1")
        let createdGroup = try await client.createSCIMGroup(body: SCIMGroupWriteRequest(displayName: "Backend Hiring"))
        #expect(createdGroup.displayName == "Backend Hiring")
        try await client.deprovisionSCIMGroup(id: "scim-g1")
    }

    @Test
    func `remaining documented gaps are routed by the mock server`() async throws {
        // The organisation-wide search answers with people and their attempts, not with
        // per-test candidate records; decoding it as the latter dropped every match.
        let globalCandidates = try await client.searchCandidates(query: "ada")
        #expect(globalCandidates.items.map(\.id) == ["cand-ada"])
        #expect(globalCandidates.items.first?.name == "Ada Lovelace")
        #expect(globalCandidates.items.first?.attempts.map(\.id) == ["c1"])
        #expect(globalCandidates.items.first?.attempts.first?.testID == "t1")

        let updatedInterview = try await client.updateInterview(
            id: "i1", options: InterviewUpdateOptions(title: "Updated")
        )
        #expect(updatedInterview.id == "i-created")
        let deletedInterview = try await client.deleteInterview(id: "i1")
        #expect(deletedInterview.status == "scheduled")

        let interviewTemplates = try await client.interviewTemplatesPage(filter: .owned)
        #expect(interviewTemplates.items.first?.id == 101)
        let interviewTemplate = try await client.interviewTemplate(id: 101)
        #expect(interviewTemplate.name == "Backend Pairing")
        #expect(interviewTemplate.status == 1)
        #expect(interviewTemplate.user == 4821)
        #expect(interviewTemplate.roles == ["8b1o41tbpiq"])
        #expect(interviewTemplate.teamShare == 1)
        #expect(interviewTemplate.questions == ["q1", "q2"])
        #expect(interviewTemplate.scorecard == 98765)
        #expect(interviewTemplate.importTemplate == true)
        #expect(interviewTemplate.editorAccess == true)
        #expect(interviewTemplate.createdAt == "2026-04-10T09:00:00Z")
        let deletedTemplate = try await client.deleteInterviewTemplate(id: 101)
        #expect(deletedTemplate.message == "Success")

        let inviteTemplates = try await client.inviteTemplatesPage(access: "company")
        #expect(inviteTemplates.items.first?.id == "tpl-1")
        let inviteTemplate = try await client.inviteTemplate(id: "tpl-1")
        #expect(inviteTemplate.subject == "Your HackerRank invite")

        let ats = try await client.createATSCodeScreenInvite(
            testID: "t1",
            requisitionID: "REQ-1",
            candidateID: "CAND-1",
            email: "ada@example.com"
        )
        #expect(ats.id == "ats-created")
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
