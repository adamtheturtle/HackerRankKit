//
//  RequestEncodingTests.swift
//  HackerRankKitTests
//

import Foundation
@testable import HackerRankKit
import Testing

@Suite("Request encoding")
struct RequestEncodingTests {
    private func encodedObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test
    func `minimal candidate invite only encodes required fields`() throws {
        let request = InviteCandidateRequest(
            email: "ada@example.com",
            fullName: nil,
            sendEmail: true,
            options: CandidateInviteOptions()
        )

        let object = try encodedObject(request)
        #expect(object["email"] as? String == "ada@example.com")
        #expect(object["send_email"] as? Bool == true)
        #expect(object["full_name"] == nil)
        #expect(object["valid_until"] == nil)
        #expect(object.count == 2)
    }

    @Test
    func `richer candidate invite encodes snake case optional fields`() throws {
        let request = InviteCandidateRequest(
            email: "ada@example.com",
            fullName: "Ada Lovelace",
            sendEmail: false,
            options: CandidateInviteOptions(
                validFrom: "2026-07-10T09:00:00Z",
                validUntil: "2026-07-17T09:00:00Z",
                emailSubject: "Welcome",
                emailMessage: "Please take this screen.",
                templateID: "template-1",
                evaluatorEmail: "reviewer@example.com",
                finishURL: "https://example.com/finish",
                resultURL: "https://example.com/result",
                notifyResultUpdate: true,
                tags: ["onsite", "priority"],
                force: true,
                allowReattempt: false,
                additionalTime: 15,
                atsCandidateID: "candidate-123",
                atsRequisitionID: "req-456"
            )
        )

        let object = try encodedObject(request)
        #expect(object["full_name"] as? String == "Ada Lovelace")
        #expect(object["send_email"] as? Bool == false)
        #expect(object["valid_from"] as? String == "2026-07-10T09:00:00Z")
        #expect(object["valid_until"] as? String == "2026-07-17T09:00:00Z")
        #expect(object["email_subject"] as? String == "Welcome")
        #expect(object["email_message"] as? String == "Please take this screen.")
        #expect(object["template_id"] as? String == "template-1")
        #expect(object["evaluator_email"] as? String == "reviewer@example.com")
        #expect(object["finish_url"] as? String == "https://example.com/finish")
        #expect(object["result_url"] as? String == "https://example.com/result")
        #expect(object["notify_result_update"] as? Bool == true)
        #expect(object["tags"] as? [String] == ["onsite", "priority"])
        #expect(object["force"] as? Bool == true)
        #expect(object["allow_reattempt"] as? Bool == false)
        #expect(object["additional_time"] as? Int == 15)
        #expect(object["ats_candidate_id"] as? String == "candidate-123")
        #expect(object["ats_requisition_id"] as? String == "req-456")
    }

    @Test
    func `candidate invite options omit blank strings and empty tag lists`() throws {
        let request = InviteCandidateRequest(
            email: "ada@example.com",
            fullName: nil,
            sendEmail: true,
            options: CandidateInviteOptions(
                validUntil: "   ",
                emailSubject: "",
                tags: ["onsite", " ", ""],
                atsCandidateID: "\n"
            )
        )

        let object = try encodedObject(request)
        #expect(object["valid_until"] == nil)
        #expect(object["email_subject"] == nil)
        #expect(object["ats_candidate_id"] == nil)
        #expect(object["tags"] as? [String] == ["onsite"])
    }

    @Test
    func `minimal test create only encodes name`() throws {
        let request = CreateTestRequest(name: "Backend Screen", options: TestWriteOptions())

        let object = try encodedObject(request)
        #expect(object["name"] as? String == "Backend Screen")
        #expect(object["duration"] == nil)
        #expect(object["cutoff_score"] == nil)
        #expect(object.count == 1)
    }

    @Test
    func `rich test create encodes snake case optional fields`() throws {
        let request = CreateTestRequest(
            name: "Backend Screen",
            options: TestWriteOptions(
                duration: 90,
                cutoffScore: 70,
                instructions: "Solve all questions.",
                startTime: "2026-07-10T09:00:00Z",
                endTime: "2026-07-17T09:00:00Z",
                languages: ["python", "go"],
                tags: ["backend", "screening"],
                library: "HackerRank",
                role: "Backend Engineer",
                skills: ["APIs", "Data Structures"],
                type: "Screen",
                questions: ["q1", "q2"],
                shuffleQuestions: true,
                enableProctoring: false
            )
        )

        let object = try encodedObject(request)
        #expect(object["name"] as? String == "Backend Screen")
        #expect(object["duration"] as? Int == 90)
        #expect(object["cutoff_score"] as? Int == 70)
        #expect(object["instructions"] as? String == "Solve all questions.")
        #expect(object["start_time"] as? String == "2026-07-10T09:00:00Z")
        #expect(object["end_time"] as? String == "2026-07-17T09:00:00Z")
        #expect(object["languages"] as? [String] == ["python", "go"])
        #expect(object["tags"] as? [String] == ["backend", "screening"])
        #expect(object["library"] as? String == "HackerRank")
        #expect(object["role"] as? String == "Backend Engineer")
        #expect(object["skills"] as? [String] == ["APIs", "Data Structures"])
        #expect(object["type"] as? String == "Screen")
        #expect(object["questions"] as? [String] == ["q1", "q2"])
        #expect(object["shuffle_questions"] as? Bool == true)
        #expect(object["enable_proctoring"] as? Bool == false)
    }

    @Test
    func `test write options omit blank strings and empty lists`() throws {
        let request = UpdateTestRequest(
            name: "Backend Screen",
            options: TestWriteOptions(
                instructions: " ",
                languages: ["python", ""],
                tags: [],
                role: "\n",
                skills: ["APIs", "  "],
                questions: ["q1", ""]
            )
        )

        let object = try encodedObject(request)
        #expect(object["instructions"] == nil)
        #expect(object["role"] == nil)
        #expect(object["tags"] == nil)
        #expect(object["languages"] as? [String] == ["python"])
        #expect(object["skills"] as? [String] == ["APIs"])
        #expect(object["questions"] as? [String] == ["q1"])
    }

    @Test
    func `question create encodes stable metadata fields`() throws {
        let request = CreateQuestionRequest(
            name: "Two Sum",
            type: "code",
            options: QuestionWriteOptions(
                status: "published",
                languages: ["python", "go"],
                problemStatement: "Return two indices.",
                recommendedDuration: 20,
                tags: ["arrays", "hashing"],
                maxScore: 100.0,
                skills: ["Problem Solving"]
            )
        )

        let object = try encodedObject(request)
        #expect(object["name"] as? String == "Two Sum")
        #expect(object["type"] as? String == "code")
        #expect(object["status"] as? String == "published")
        #expect(object["languages"] as? [String] == ["python", "go"])
        #expect(object["problem_statement"] as? String == "Return two indices.")
        #expect(object["recommended_duration"] as? Int == 20)
        #expect(object["tags"] as? [String] == ["arrays", "hashing"])
        #expect(object["max_score"] as? Double == 100.0)
        #expect(object["skills"] as? [String] == ["Problem Solving"])
    }

    @Test
    func `question update omits unset and blank metadata fields`() throws {
        let request = UpdateQuestionRequest(
            name: nil,
            type: " ",
            options: QuestionWriteOptions(
                status: "",
                languages: ["python", ""],
                problemStatement: "\n",
                tags: [],
                skills: ["Algorithms", " "]
            )
        )

        let object = try encodedObject(request)
        #expect(object["name"] == nil)
        #expect(object["type"] == nil)
        #expect(object["status"] == nil)
        #expect(object["problem_statement"] == nil)
        #expect(object["tags"] == nil)
        #expect(object["languages"] as? [String] == ["python"])
        #expect(object["skills"] as? [String] == ["Algorithms"])
    }

    @Test
    func `candidate update encodes documented optional fields`() throws {
        let request = UpdateCandidateRequest(
            options: CandidateUpdateOptions(
                fullName: "Ada Lovelace",
                atsState: 2,
                inviteValidFrom: "2026-07-10T09:00:00Z",
                inviteMetadata: ["ats_candidate_id": .string("cand-1")],
                testResultURL: "https://example.com/result",
                acceptResultUpdates: true,
                tags: ["priority", ""],
                accommodations: ["extra_time": .int(15)]
            )
        )

        let object = try encodedObject(request)
        #expect(object["full_name"] as? String == "Ada Lovelace")
        #expect(object["ats_state"] as? Int == 2)
        #expect(object["invite_valid_from"] as? String == "2026-07-10T09:00:00Z")
        #expect((object["invite_metadata"] as? [String: Any])?["ats_candidate_id"] as? String == "cand-1")
        #expect(object["test_result_url"] as? String == "https://example.com/result")
        #expect(object["accept_result_updates"] as? Bool == true)
        #expect(object["tags"] as? [String] == ["priority"])
        #expect((object["accommodations"] as? [String: Any])?["extra_time"] as? Int == 15)
    }

    @Test
    func `user and team updates encode snake case fields`() throws {
        let user = try encodedObject(UpdateUserRequest(options: UserUpdateOptions(
            firstName: "Rhea",
            questionsPermission: 3,
            sharedCandidatesPermission: 2,
            companyAdmin: true
        )))
        #expect(user["firstname"] as? String == "Rhea")
        #expect(user["questions_permission"] as? Int == 3)
        #expect(user["shared_candidates_permission"] as? Int == 2)
        #expect(user["company_admin"] as? Bool == true)

        let team = try encodedObject(UpdateTeamRequest(options: TeamUpdateOptions(
            name: "Backend Hiring",
            recruiterCap: 5,
            inviteAs: "Hiring Team",
            locations: ["London", ""]
        )))
        #expect(team["name"] as? String == "Backend Hiring")
        #expect(team["recruiter_cap"] as? Int == 5)
        #expect(team["invite_as"] as? String == "Hiring Team")
        #expect(team["locations"] as? [String] == ["London"])
    }
}
