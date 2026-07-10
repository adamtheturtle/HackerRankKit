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
}
