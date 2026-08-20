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
        #expect(object["invite_valid_to"] == nil)
        #expect(object.count == 2)
    }

    @Test
    func `richer candidate invite encodes the schema's field names`() throws {
        let request = InviteCandidateRequest(
            email: "ada@example.com",
            fullName: "Ada Lovelace",
            sendEmail: false,
            options: CandidateInviteOptions(
                inviteValidFrom: "2026-07-10T09:00:00Z",
                inviteValidTo: "2026-07-17T09:00:00Z",
                subject: "Welcome",
                message: "Please take this screen.",
                template: "template-1",
                evaluatorEmail: "reviewer@example.com",
                testFinishURL: "https://example.com/finish",
                testResultURL: "https://example.com/result",
                webhookAuthentication: .bearerToken("s3cret"),
                acceptResultUpdates: true,
                tags: ["onsite", "priority"],
                force: true,
                forceReattempt: false,
                accommodations: CandidateAccommodations(additionalTimePercent: 25)
            )
        )

        let object = try encodedObject(request)
        #expect(object["full_name"] as? String == "Ada Lovelace")
        #expect(object["send_email"] as? Bool == false)
        #expect(object["invite_valid_from"] as? String == "2026-07-10T09:00:00Z")
        #expect(object["invite_valid_to"] as? String == "2026-07-17T09:00:00Z")
        #expect(object["subject"] as? String == "Welcome")
        #expect(object["message"] as? String == "Please take this screen.")
        #expect(object["template"] as? String == "template-1")
        #expect(object["evaluator_email"] as? String == "reviewer@example.com")
        #expect(object["test_finish_url"] as? String == "https://example.com/finish")
        #expect(object["test_result_url"] as? String == "https://example.com/result")
        #expect(object["accept_result_updates"] as? Bool == true)
        #expect(object["tags"] as? [String] == ["onsite", "priority"])
        #expect(object["force"] as? Bool == true)
        #expect(object["force_reattempt"] as? Bool == false)

        // The webhook the results are posted to must carry its authentication.
        let authentication = try #require(object["webhook_authentication"] as? [String: Any])
        #expect(authentication["type"] as? String == "bearer_token")
        #expect((authentication["data"] as? [String: Any])?["token"] as? String == "s3cret")

        // Additional time is a percentage of the test duration, nested in accommodations.
        let accommodations = try #require(object["accommodations"] as? [String: Any])
        #expect(accommodations["additional_time_percent"] as? Int == 25)

        // None of the keys the schema does not define are sent.
        for absent in ["valid_from", "valid_until", "email_subject", "email_message", "template_id",
                       "finish_url", "result_url", "notify_result_update", "allow_reattempt",
                       "additional_time", "ats_candidate_id", "ats_requisition_id"] {
            #expect(object[absent] == nil, "\(absent) is not a documented invite field")
        }
    }

    @Test
    func `candidate invite options omit blank strings and empty tag lists`() throws {
        let request = InviteCandidateRequest(
            email: "ada@example.com",
            fullName: nil,
            sendEmail: true,
            options: CandidateInviteOptions(
                inviteValidTo: "   ",
                subject: "",
                template: "\n",
                tags: ["onsite", " ", ""]
            )
        )

        let object = try encodedObject(request)
        #expect(object["invite_valid_to"] == nil)
        #expect(object["subject"] == nil)
        #expect(object["template"] == nil)
        #expect(object["tags"] as? [String] == ["onsite"])
    }

    @Test
    func `rich test create encodes snake case optional fields`() throws {
        let request = CreateTestRequest(
            name: "Backend Screen",
            duration: 90,
            roleIDs: ["role-be"],
            experience: ["Senior"],
            options: TestWriteOptions(
                cutoffScore: 70,
                instructions: "Solve all questions.",
                startTime: "2026-07-10T09:00:00Z",
                endTime: "2026-07-17T09:00:00Z",
                languages: ["python", "go"],
                tags: ["backend", "screening"],
                questions: ["q1", "q2"],
                shuffleQuestions: true,
                enableProctoring: false
            )
        )

        let object = try encodedObject(request)
        #expect(object["name"] as? String == "Backend Screen")
        #expect(object["duration"] as? Int == 90)
        #expect(object["role_ids"] as? [String] == ["role-be"])
        #expect(object["experience"] as? [String] == ["Senior"])
        #expect(object["cutoff_score"] as? Int == 70)
        #expect(object["instructions"] as? String == "Solve all questions.")
        // The schema spells the assessment window `starttime`/`endtime`, without underscores.
        #expect(object["starttime"] as? String == "2026-07-10T09:00:00Z")
        #expect(object["endtime"] as? String == "2026-07-17T09:00:00Z")
        #expect(object["start_time"] == nil)
        #expect(object["end_time"] == nil)
        #expect(object["languages"] as? [String] == ["python", "go"])
        #expect(object["tags"] as? [String] == ["backend", "screening"])
        #expect(object["questions"] as? [String] == ["q1", "q2"])
        #expect(object["shuffle_questions"] as? Bool == true)
        #expect(object["enable_proctoring"] as? Bool == false)
    }

    @Test
    func `test create always sends the schema's required fields`() throws {
        // `TestsCreate` requires name, duration, role_ids and experience; a name-only body
        // is rejected by the live API.
        let request = CreateTestRequest(
            name: "Screen", duration: 45, roleIDs: ["r1"], experience: ["Mid"], options: TestWriteOptions()
        )

        let object = try encodedObject(request)
        #expect(Set(object.keys) == ["name", "duration", "role_ids", "experience"])
    }

    @Test
    func `a create ignores the option copies of its required fields`() throws {
        // The explicit parameters are the contract; an option value must not contradict them.
        let request = CreateTestRequest(
            name: "Screen",
            duration: 45,
            roleIDs: ["r1"],
            experience: ["Mid"],
            options: TestWriteOptions(duration: 999, roleIDs: ["other"], experience: ["Junior"])
        )

        let object = try encodedObject(request)
        #expect(object["duration"] as? Int == 45)
        #expect(object["role_ids"] as? [String] == ["r1"])
        #expect(object["experience"] as? [String] == ["Mid"])
    }

    @Test
    func `a test update can set the fields a create requires`() throws {
        let request = UpdateTestRequest(
            name: "Screen",
            options: TestWriteOptions(duration: 30, roleIDs: ["r2"], experience: ["Staff"])
        )

        let object = try encodedObject(request)
        #expect(object["duration"] as? Int == 30)
        #expect(object["role_ids"] as? [String] == ["r2"])
        #expect(object["experience"] as? [String] == ["Staff"])
    }

    @Test
    func `test write options preserve explicit language and tag clears`() throws {
        let request = UpdateTestRequest(
            name: "Backend Screen",
            options: TestWriteOptions(
                instructions: " ",
                languages: ["python", ""],
                tags: [],
                roleIDs: ["r1", "  "],
                questions: ["q1", ""]
            )
        )

        let object = try encodedObject(request)
        #expect(object["instructions"] == nil)
        #expect(object["tags"] as? [String] == [])
        #expect(object["languages"] as? [String] == ["python"])
        #expect(object["role_ids"] as? [String] == ["r1"])
        #expect(object["questions"] as? [String] == ["q1"])

        let clearObject = try encodedObject(UpdateTestRequest(
            name: "Backend Screen",
            options: TestWriteOptions(languages: [], tags: [" "])
        ))
        #expect(clearObject["languages"] as? [String] == [])
        #expect(clearObject["tags"] as? [String] == [])
    }

    @Test
    func `question create encodes the schema's required and optional fields`() throws {
        let request = CreateQuestionRequest(
            name: "Two Sum",
            type: "code",
            problemStatement: "Return two indices.",
            recommendedDuration: 20,
            options: QuestionWriteOptions(
                languages: ["python", "go"],
                internalNotes: "Swap the distractor next revision.",
                tags: ["arrays", "hashing"]
            )
        )

        let object = try encodedObject(request)
        #expect(object["name"] as? String == "Two Sum")
        #expect(object["type"] as? String == "code")
        #expect(object["problem_statement"] as? String == "Return two indices.")
        #expect(object["recommended_duration"] as? Int == 20)
        #expect(object["languages"] as? [String] == ["python", "go"])
        #expect(object["internal_notes"] as? String == "Swap the distractor next revision.")
        #expect(object["tags"] as? [String] == ["arrays", "hashing"])
        // None of these are defined by the question write schemas.
        #expect(object["status"] == nil)
        #expect(object["max_score"] == nil)
        #expect(object["skills"] == nil)
    }

    @Test
    func `an mcq question is created with its options and answer`() throws {
        let single = try encodedObject(CreateQuestionRequest(
            name: "SQL Joins",
            type: "mcq",
            problemStatement: "Which join keeps unmatched left rows?",
            recommendedDuration: 5,
            options: QuestionWriteOptions(mcqOptions: ["INNER", "LEFT"], answer: .option(2))
        ))
        #expect(single["options"] as? [String] == ["INNER", "LEFT"])
        #expect(single["answer"] as? Int == 2)

        let multiple = try encodedObject(UpdateQuestionRequest(
            name: nil,
            type: nil,
            options: QuestionWriteOptions(answer: .options([1, 3]))
        ))
        #expect(multiple["answer"] as? [Int] == [1, 3])
    }

    @Test
    func `a question create ignores the option copies of its required fields`() throws {
        let request = CreateQuestionRequest(
            name: "Two Sum",
            type: "code",
            problemStatement: "Return two indices.",
            recommendedDuration: 20,
            options: QuestionWriteOptions(problemStatement: "Something else", recommendedDuration: 999)
        )

        let object = try encodedObject(request)
        #expect(object["problem_statement"] as? String == "Return two indices.")
        #expect(object["recommended_duration"] as? Int == 20)
    }

    @Test
    func `question update preserves explicit metadata clears`() throws {
        let request = UpdateQuestionRequest(
            name: nil,
            type: " ",
            options: QuestionWriteOptions(
                languages: ["python", ""],
                problemStatement: "\n",
                internalNotes: "  ",
                tags: []
            )
        )

        let object = try encodedObject(request)
        #expect(object["name"] == nil)
        #expect(object["type"] == nil)
        #expect(object["problem_statement"] == nil)
        #expect(object["tags"] as? [String] == [])
        #expect(object["languages"] as? [String] == ["python"])
        // An explicit empty note is a clear, so it survives onto the wire.
        #expect(object["internal_notes"] as? String == "")
    }

    @Test
    func `question update encodes an explicit duration clear as null`() throws {
        let request = UpdateQuestionRequest(
            name: nil,
            type: nil,
            options: QuestionWriteOptions(clearsRecommendedDuration: true)
        )

        let object = try encodedObject(request)
        #expect(object["recommended_duration"] is NSNull)
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

        let clearedTags = try encodedObject(UpdateCandidateRequest(
            options: CandidateUpdateOptions(tags: [])
        ))
        #expect(clearedTags["tags"] as? [String] == [])
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

        let clearedUserFields = try encodedObject(UpdateUserRequest(options: UserUpdateOptions(
            lastName: "  ",
            country: "",
            phone: "\n"
        )))
        #expect(clearedUserFields["lastname"] as? String == "")
        #expect(clearedUserFields["country"] as? String == "")
        #expect(clearedUserFields["phone"] as? String == "")

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

        let clearedTeamCollections = try encodedObject(UpdateTeamRequest(options: TeamUpdateOptions(
            locations: [],
            departments: ["  "]
        )))
        #expect(clearedTeamCollections["locations"] as? [String] == [])
        #expect(clearedTeamCollections["departments"] as? [String] == [])
    }

    @Test
    func `ats invite requests encode documented fields`() throws {
        let codePair = try encodedObject(ATSCodePairRequest(
            title: "Backend Interview",
            requisitionID: "REQ-1",
            candidateID: "CAND-1",
            options: ATSCodePairOptions(
                candidate: ["email": .string("ada@example.com")],
                sendEmail: true,
                interviewMetadata: ["source": .string("ats")]
            )
        ))
        #expect(codePair["title"] as? String == "Backend Interview")
        #expect(codePair["requisition_id"] as? String == "REQ-1")
        #expect(codePair["candidate_id"] as? String == "CAND-1")
        #expect((codePair["candidate"] as? [String: Any])?["email"] as? String == "ada@example.com")
        #expect(codePair["send_email"] as? Bool == true)

        let codeScreen = try encodedObject(ATSCodeScreenRequest(
            testID: "t1",
            requisitionID: "REQ-1",
            candidateID: "CAND-1",
            email: "ada@example.com",
            options: ATSCodeScreenOptions(
                testResultURL: "https://example.com/result",
                acceptResultUpdates: true,
                force: true,
                forceReattemptAfter: 3600,
                accommodations: ["extra_time": .int(10)]
            )
        ))
        #expect(codeScreen["test_id"] as? String == "t1")
        #expect(codeScreen["requisition_id"] as? String == "REQ-1")
        #expect(codeScreen["candidate_id"] as? String == "CAND-1")
        #expect(codeScreen["email"] as? String == "ada@example.com")
        #expect(codeScreen["test_result_url"] as? String == "https://example.com/result")
        #expect(codeScreen["accept_result_updates"] as? Bool == true)
        #expect(codeScreen["force"] as? Bool == true)
        #expect(codeScreen["force_reattempt_after"] as? Int == 3600)
    }

    @Test
    func `scim requests encode provisioning bodies`() throws {
        let user = try encodedObject(SCIMUserWriteRequest(
            userName: "rhea@example.com",
            name: ["givenName": .string("Rhea")],
            email: "rhea@example.com",
            additionalEmails: ["rhea.recruiter@example.com", "  "],
            active: true,
            role: "recruiter",
            teamAdmin: true,
            companyAdmin: false,
            schemas: ["urn:ietf:params:scim:schemas:core:2.0:User", ""]
        ))
        #expect(user["userName"] as? String == "rhea@example.com")
        #expect(user["active"] as? Bool == true)
        #expect(user["role"] as? String == "recruiter")
        #expect(user["team_admin"] as? Bool == true)
        #expect(user["company_admin"] as? Bool == false)
        #expect((user["name"] as? [String: Any])?["givenName"] as? String == "Rhea")
        // The required email list always carries the primary address first, encoded as
        // SCIM multi-valued objects — plain strings are rejected by the live service.
        let emails = try #require(user["emails"] as? [[String: Any]])
        #expect(emails.count == 2)
        #expect(emails[0]["value"] as? String == "rhea@example.com")
        #expect(emails[0]["primary"] as? Bool == true)
        #expect(emails[1]["value"] as? String == "rhea.recruiter@example.com")
        #expect(emails[1]["primary"] as? Bool == false)
        #expect(user["schemas"] as? [String] == ["urn:ietf:params:scim:schemas:core:2.0:User"])

        let group = try encodedObject(SCIMGroupWriteRequest(
            displayName: "Backend Hiring",
            members: [.object(["value": .string("scim-u1")])]
        ))
        // HackerRank's SCIM group schema spells the key `diplayName`; the correctly
        // spelled one is not read, so a group would have been created unnamed.
        #expect(group["diplayName"] as? String == "Backend Hiring")
        #expect(group["displayName"] == nil)
        #expect((group["members"] as? [[String: Any]])?.first?["value"] as? String == "scim-u1")

        let patch = try encodedObject(SCIMPatchRequest(operations: [
            SCIMPatchOperation(op: "replace", path: "active", value: .bool(false))
        ]))
        #expect(patch["schemas"] as? [String] == ["urn:ietf:params:scim:api:messages:2.0:PatchOp"])
        let operations = try #require(patch["Operations"] as? [[String: Any]])
        #expect(operations.first?["op"] as? String == "replace")
        #expect(operations.first?["path"] as? String == "active")
        #expect(operations.first?["value"] as? Bool == false)
    }

    @Test
    func `question operation requests encode first class bodies`() throws {
        let stubs = try encodedObject(CustomCodeStubsRequest(stubs: [
            QuestionCodeStub(language: "swift", body: "func solve() {}")
        ]))
        let templates = try #require(stubs["templates"] as? [[String: Any]])
        #expect(templates.first?["language"] as? String == "swift")
        #expect(templates.first?["body"] as? String == "func solve() {}")

        let generation = try encodedObject(GenerateCodeStubsRequest(options: CodeStubGenerationOptions(
            functionName: "twoSum",
            functionParams: "INTEGER_ARRAY nums",
            functionReturn: "INTEGER_ARRAY",
            allowedLanguages: ["c", "", "clojure"]
        )))
        #expect(generation["functionName"] as? String == "twoSum")
        #expect(generation["functionParams"] as? String == "INTEGER_ARRAY nums")
        #expect(generation["functionReturn"] as? String == "INTEGER_ARRAY")
        // The languages go as one comma-separated value, blanks dropped.
        #expect(generation["allowedLanguages"] as? String == "c,clojure")

        let testcase = try encodedObject(QuestionTestcaseRequest(options: QuestionTestcaseOptions(
            explanation: "",
            input: "input",
            output: "output",
            name: "Sample",
            qid: 1,
            sample: false,
            score: 10,
            type: "easy"
        )))
        #expect(testcase["explanation"] as? String == "")
        #expect(testcase["input"] as? String == "input")
        #expect(testcase["output"] as? String == "output")
        #expect(testcase["name"] as? String == "Sample")
        #expect(testcase["qid"] as? Int == 1)
        #expect(testcase["sample"] as? Int == 0)
        #expect(testcase["score"] as? Int == 10)
        #expect(testcase["type"] as? String == "easy")
    }

    @Test
    func `interview write requests encode typed optional fields`() throws {
        let interview = try encodedObject(UpdateInterviewRequest(options: InterviewUpdateOptions(
            title: "Backend Pairing",
            from: "2026-07-10T09:00:00Z",
            to: "2026-07-10T10:00:00Z",
            candidate: InterviewCandidate(email: "ada@example.com", name: "Ada Lovelace"),
            interviewers: ["ian@example.com", ""],
            notes: "Discuss APIs",
            resumeURL: "https://example.com/cv.pdf",
            resultURL: "https://example.com/webhook",
            sendEmail: true,
            metadata: ["ats_id": .string("req-1")],
            interviewTemplateID: 101,
            aiAssistantAvailable: false
        )))
        #expect(interview["title"] as? String == "Backend Pairing")
        #expect(interview["from"] as? String == "2026-07-10T09:00:00Z")
        #expect(interview["to"] as? String == "2026-07-10T10:00:00Z")
        // The candidate is an object, not a bare email string.
        #expect((interview["candidate"] as? [String: Any])?["email"] as? String == "ada@example.com")
        #expect((interview["candidate"] as? [String: Any])?["name"] as? String == "Ada Lovelace")
        #expect(interview["interviewers"] as? [String] == ["ian@example.com"])
        // Interviewers are only applied when the replacement flag goes with them.
        #expect(interview["replace_interviewers"] as? Bool == true)
        #expect(interview["notes"] as? String == "Discuss APIs")
        #expect(interview["resume_url"] as? String == "https://example.com/cv.pdf")
        #expect(interview["result_url"] as? String == "https://example.com/webhook")
        #expect(interview["send_email"] as? Bool == true)
        #expect((interview["metadata"] as? [String: Any])?["ats_id"] as? String == "req-1")
        #expect(interview["interview_template_id"] as? Int == 101)
        #expect(interview["ai_assistant_available"] as? Bool == false)

        // An interview update can clear the fields it set.
        let cleared = try encodedObject(UpdateInterviewRequest(options: InterviewUpdateOptions(
            title: "", interviewers: [], notes: "  "
        )))
        #expect(cleared["title"] as? String == "")
        #expect(cleared["notes"] as? String == "")
        #expect(cleared["interviewers"] as? [String] == [])
        #expect(cleared["replace_interviewers"] as? Bool == true)

        // An omitted update stays omitted, and never claims to replace the interviewers.
        let untouched = try encodedObject(UpdateInterviewRequest(options: InterviewUpdateOptions()))
        #expect(untouched.isEmpty)
    }

    @Test
    func `interview template writes encode each endpoint's own fields`() throws {
        let created = try encodedObject(CreateInterviewTemplateRequest(
            name: "Backend Template",
            options: InterviewTemplateCreateOptions(roleID: "8b1o41tbpiq", teamShare: 2, questionIDs: [1_939_659])
        ))
        #expect(created["name"] as? String == "Backend Template")
        #expect(created["role_id"] as? String == "8b1o41tbpiq")
        #expect(created["team_share"] as? Int == 2)
        // Questions go under `question_ids`, as integers.
        #expect(created["question_ids"] as? [Int] == [1_939_659])
        for absent in ["title", "description", "tags", "metadata", "questions"] {
            #expect(created[absent] == nil, "\(absent) is not a documented template create field")
        }

        let updated = try encodedObject(UpdateInterviewTemplateRequest(
            options: InterviewTemplateUpdateOptions(
                name: "Renamed Template", roleID: "8b1o41tbpiq", teamShare: 1, scorecardID: 98765
            )
        ))
        #expect(updated["name"] as? String == "Renamed Template")
        #expect(updated["role_id"] as? String == "8b1o41tbpiq")
        #expect(updated["team_share"] as? Int == 1)
        #expect(updated["scorecard_id"] as? Int == 98765)
        // The update endpoint sets no question list at all.
        #expect(updated["question_ids"] == nil)
        #expect(updated["questions"] == nil)
    }
}
