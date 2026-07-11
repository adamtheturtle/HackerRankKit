//
//  Requests.swift
//  HackerRankKit
//

import Foundation

// The request bodies and response echoes for `HackerRankClient`'s write flows.
// The request types are module-internal (only the client builds them); the response
// echoes are public (they are the return types of the client's write methods) and
// all-optional so a 2xx never fails to decode on an unexpected shape.

/// The body sent when inviting a candidate to a test. Encoded as the API's
/// snake-case JSON; a blank name is omitted entirely rather than sent empty.
nonisolated struct InviteCandidateRequest: Encodable {
    let email: String
    let fullName: String?
    let sendEmail: Bool
    let options: CandidateInviteOptions

    enum CodingKeys: String, CodingKey {
        case email
        case fullName = "full_name"
        case sendEmail = "send_email"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case emailSubject = "email_subject"
        case emailMessage = "email_message"
        case templateID = "template_id"
        case evaluatorEmail = "evaluator_email"
        case finishURL = "finish_url"
        case resultURL = "result_url"
        case notifyResultUpdate = "notify_result_update"
        case tags
        case force
        case allowReattempt = "allow_reattempt"
        case additionalTime = "additional_time"
        case atsCandidateID = "ats_candidate_id"
        case atsRequisitionID = "ats_requisition_id"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(fullName, forKey: .fullName)
        try container.encode(sendEmail, forKey: .sendEmail)
        try container.encodeIfPresent(options.validFrom, forKey: .validFrom)
        try container.encodeIfPresent(options.validUntil, forKey: .validUntil)
        try container.encodeIfPresent(options.emailSubject, forKey: .emailSubject)
        try container.encodeIfPresent(options.emailMessage, forKey: .emailMessage)
        try container.encodeIfPresent(options.templateID, forKey: .templateID)
        try container.encodeIfPresent(options.evaluatorEmail, forKey: .evaluatorEmail)
        try container.encodeIfPresent(options.finishURL, forKey: .finishURL)
        try container.encodeIfPresent(options.resultURL, forKey: .resultURL)
        try container.encodeIfPresent(options.notifyResultUpdate, forKey: .notifyResultUpdate)
        try container.encodeIfPresent(options.tags, forKey: .tags)
        try container.encodeIfPresent(options.force, forKey: .force)
        try container.encodeIfPresent(options.allowReattempt, forKey: .allowReattempt)
        try container.encodeIfPresent(options.additionalTime, forKey: .additionalTime)
        try container.encodeIfPresent(options.atsCandidateID, forKey: .atsCandidateID)
        try container.encodeIfPresent(options.atsRequisitionID, forKey: .atsRequisitionID)
    }
}

/// Optional fields for a candidate invite. Values are omitted from the request when unset,
/// so callers can opt into richer API support without changing the minimal invite path.
public nonisolated struct CandidateInviteOptions: Sendable, Equatable {
    /// ISO-8601 time before which the invite should not be usable.
    public let validFrom: String?
    /// ISO-8601 time after which the invite should expire.
    public let validUntil: String?
    /// Custom invitation email subject.
    public let emailSubject: String?
    /// Custom invitation email body/message.
    public let emailMessage: String?
    /// Invitation email template identifier.
    public let templateID: String?
    /// Evaluator email address assigned to the invite.
    public let evaluatorEmail: String?
    /// URL the candidate is sent to after finishing.
    public let finishURL: String?
    /// URL for downstream result/report callbacks or redirects.
    public let resultURL: String?
    /// Whether to notify downstream systems when results update.
    public let notifyResultUpdate: Bool?
    /// Tags to attach to the candidate invite.
    public let tags: [String]?
    /// Whether to force creation when the API supports it.
    public let force: Bool?
    /// Whether the candidate is allowed to reattempt.
    public let allowReattempt: Bool?
    /// Additional time accommodation, in minutes.
    public let additionalTime: Int?
    /// External ATS candidate identifier.
    public let atsCandidateID: String?
    /// External ATS requisition/job identifier.
    public let atsRequisitionID: String?

    public init(
        validFrom: String? = nil,
        validUntil: String? = nil,
        emailSubject: String? = nil,
        emailMessage: String? = nil,
        templateID: String? = nil,
        evaluatorEmail: String? = nil,
        finishURL: String? = nil,
        resultURL: String? = nil,
        notifyResultUpdate: Bool? = nil,
        tags: [String]? = nil,
        force: Bool? = nil,
        allowReattempt: Bool? = nil,
        additionalTime: Int? = nil,
        atsCandidateID: String? = nil,
        atsRequisitionID: String? = nil
    ) {
        self.validFrom = Self.nonBlank(validFrom)
        self.validUntil = Self.nonBlank(validUntil)
        self.emailSubject = Self.nonBlank(emailSubject)
        self.emailMessage = Self.nonBlank(emailMessage)
        self.templateID = Self.nonBlank(templateID)
        self.evaluatorEmail = Self.nonBlank(evaluatorEmail)
        self.finishURL = Self.nonBlank(finishURL)
        self.resultURL = Self.nonBlank(resultURL)
        self.notifyResultUpdate = notifyResultUpdate
        let cleanedTags = tags?.compactMap(Self.nonBlank)
        self.tags = cleanedTags?.isEmpty == false ? cleanedTags : nil
        self.force = force
        self.allowReattempt = allowReattempt
        self.additionalTime = additionalTime
        self.atsCandidateID = Self.nonBlank(atsCandidateID)
        self.atsRequisitionID = Self.nonBlank(atsRequisitionID)
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// The candidate record echoed back by a successful invite. Every field is optional so a
/// 2xx response never fails to decode on an unexpected shape — the invite is what matters,
/// not parsing the echo.
public nonisolated struct InvitedCandidate: Decodable, Sendable {
    public let id: String?
    public let email: String?
}

/// The body sent when creating a user. Snake-case to match the API; blank optional
/// fields are omitted. The server requires `teams` (an array of team-id objects) along
/// with `email`, `firstname`, and `role`; it rejects a create without them.
nonisolated struct CreateUserRequest: Encodable {
    let email: String
    let firstName: String?
    let lastName: String?
    let role: String?
    let teams: [TeamRef]?

    /// The API's team reference shape on a user create: an object holding the team's id.
    struct TeamRef: Encodable {
        let id: String
    }

    enum CodingKeys: String, CodingKey {
        case email
        case firstName = "firstname"
        case lastName = "lastname"
        case role
        case teams
    }
}

/// The user record echoed back by a successful create. All-optional so a 2xx never fails to
/// decode on an unexpected shape.
public nonisolated struct CreatedUser: Decodable, Sendable {
    public let id: String?
    public let email: String?
}

/// The body sent when creating a question. The stable metadata fields are modelled here;
/// type-specific authoring payloads can layer on later without changing this first slice.
nonisolated struct CreateQuestionRequest: Encodable {
    let name: String
    let type: String
    let options: QuestionWriteOptions
}

/// The body sent when updating question metadata.
nonisolated struct UpdateQuestionRequest: Encodable {
    let name: String?
    let type: String?
    let options: QuestionWriteOptions
}

private enum QuestionWriteCodingKeys: String, CodingKey {
    case name
    case type
    case status
    case languages
    case problemStatement = "problem_statement"
    case recommendedDuration = "recommended_duration"
    case tags
    case maxScore = "max_score"
    case skills
}

extension CreateQuestionRequest {
    nonisolated func encode(to encoder: any Encoder) throws {
        try encodeQuestionWriteBody(to: encoder, name: name, type: type, options: options)
    }
}

extension UpdateQuestionRequest {
    nonisolated func encode(to encoder: any Encoder) throws {
        try encodeQuestionWriteBody(to: encoder, name: name, type: type, options: options)
    }
}

private nonisolated func encodeQuestionWriteBody(
    to encoder: any Encoder,
    name: String?,
    type: String?,
    options: QuestionWriteOptions
) throws {
    var container = encoder.container(keyedBy: QuestionWriteCodingKeys.self)
    try container.encodeIfPresent(nonBlank(name), forKey: .name)
    try container.encodeIfPresent(nonBlank(type), forKey: .type)
    try container.encodeIfPresent(options.status, forKey: .status)
    try container.encodeIfPresent(options.languages, forKey: .languages)
    try container.encodeIfPresent(options.problemStatement, forKey: .problemStatement)
    try container.encodeIfPresent(options.recommendedDuration, forKey: .recommendedDuration)
    try container.encodeIfPresent(options.tags, forKey: .tags)
    try container.encodeIfPresent(options.maxScore, forKey: .maxScore)
    try container.encodeIfPresent(options.skills, forKey: .skills)
}

private nonisolated func nonBlank(_ value: String?) -> String? {
    let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return result?.isEmpty == false ? result : nil
}

/// Optional stable metadata fields for creating or updating questions. The full question
/// authoring surface is type-specific, so this first slice intentionally sticks to fields
/// shared by the list/detail models.
public nonisolated struct QuestionWriteOptions: Sendable, Equatable {
    /// Question lifecycle status.
    public let status: String?
    /// Allowed programming languages for coding questions.
    public let languages: [String]?
    /// Problem statement, typically Markdown or HTML.
    public let problemStatement: String?
    /// Recommended solving duration in minutes.
    public let recommendedDuration: Int?
    /// Tags to attach to the question.
    public let tags: [String]?
    /// Maximum achievable score.
    public let maxScore: Double?
    /// Skills assessed by the question.
    public let skills: [String]?

    public init(
        status: String? = nil,
        languages: [String]? = nil,
        problemStatement: String? = nil,
        recommendedDuration: Int? = nil,
        tags: [String]? = nil,
        maxScore: Double? = nil,
        skills: [String]? = nil
    ) {
        self.status = Self.nonBlank(status)
        self.languages = Self.cleanList(languages)
        self.problemStatement = Self.nonBlank(problemStatement)
        self.recommendedDuration = recommendedDuration
        self.tags = Self.cleanList(tags)
        self.maxScore = maxScore
        self.skills = Self.cleanList(skills)
    }

    private static func cleanList(_ values: [String]?) -> [String]? {
        let cleaned = values?.compactMap(nonBlank)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// The question echoed back by a successful create/update/delete. All-optional so a 2xx
/// never fails to decode on an unexpected shape.
public nonisolated struct WrittenQuestion: Decodable, Sendable {
    public let id: String?
    public let name: String?
    public let type: String?
}

/// The body sent when creating a test.
nonisolated struct CreateTestRequest: Encodable {
    let name: String
    let options: TestWriteOptions
}

/// The body sent when renaming a test.
nonisolated struct UpdateTestRequest: Encodable {
    let name: String
    let options: TestWriteOptions
}

extension CreateTestRequest {
    enum CodingKeys: String, CodingKey {
        case name
        case duration
        case cutoffScore = "cutoff_score"
        case instructions
        case startTime = "start_time"
        case endTime = "end_time"
        case languages
        case tags
        case library
        case role
        case skills
        case type
        case questions
        case shuffleQuestions = "shuffle_questions"
        case enableProctoring = "enable_proctoring"
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        try encodeTestWriteBody(to: encoder, name: name, options: options)
    }
}

extension UpdateTestRequest {
    enum CodingKeys: String, CodingKey {
        case name
        case duration
        case cutoffScore = "cutoff_score"
        case instructions
        case startTime = "start_time"
        case endTime = "end_time"
        case languages
        case tags
        case library
        case role
        case skills
        case type
        case questions
        case shuffleQuestions = "shuffle_questions"
        case enableProctoring = "enable_proctoring"
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        try encodeTestWriteBody(to: encoder, name: name, options: options)
    }
}

private nonisolated func encodeTestWriteBody(to encoder: any Encoder, name: String, options: TestWriteOptions) throws {
    var container = encoder.container(keyedBy: CreateTestRequest.CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(options.duration, forKey: .duration)
    try container.encodeIfPresent(options.cutoffScore, forKey: .cutoffScore)
    try container.encodeIfPresent(options.instructions, forKey: .instructions)
    try container.encodeIfPresent(options.startTime, forKey: .startTime)
    try container.encodeIfPresent(options.endTime, forKey: .endTime)
    try container.encodeIfPresent(options.languages, forKey: .languages)
    try container.encodeIfPresent(options.tags, forKey: .tags)
    try container.encodeIfPresent(options.library, forKey: .library)
    try container.encodeIfPresent(options.role, forKey: .role)
    try container.encodeIfPresent(options.skills, forKey: .skills)
    try container.encodeIfPresent(options.type, forKey: .type)
    try container.encodeIfPresent(options.questions, forKey: .questions)
    try container.encodeIfPresent(options.shuffleQuestions, forKey: .shuffleQuestions)
    try container.encodeIfPresent(options.enableProctoring, forKey: .enableProctoring)
}

/// Optional fields for creating or updating an assessment. Values are omitted when unset,
/// so the existing name-only create/update calls stay minimal.
public nonisolated struct TestWriteOptions: Sendable, Equatable {
    /// Duration of the assessment in minutes.
    public let duration: Int?
    /// Passing score threshold.
    public let cutoffScore: Int?
    /// Candidate-facing instructions.
    public let instructions: String?
    /// ISO-8601 assessment window start.
    public let startTime: String?
    /// ISO-8601 assessment window end.
    public let endTime: String?
    /// Allowed programming languages.
    public let languages: [String]?
    /// Tags to attach to the assessment.
    public let tags: [String]?
    /// Source library/collection metadata.
    public let library: String?
    /// Hiring role metadata.
    public let role: String?
    /// Skills assessed by the test.
    public let skills: [String]?
    /// Assessment type/category.
    public let type: String?
    /// Question identifiers included in the assessment.
    public let questions: [String]?
    /// Whether question order should be shuffled.
    public let shuffleQuestions: Bool?
    /// Whether proctoring should be enabled.
    public let enableProctoring: Bool?

    public init(
        duration: Int? = nil,
        cutoffScore: Int? = nil,
        instructions: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        languages: [String]? = nil,
        tags: [String]? = nil,
        library: String? = nil,
        role: String? = nil,
        skills: [String]? = nil,
        type: String? = nil,
        questions: [String]? = nil,
        shuffleQuestions: Bool? = nil,
        enableProctoring: Bool? = nil
    ) {
        self.duration = duration
        self.cutoffScore = cutoffScore
        self.instructions = Self.nonBlank(instructions)
        self.startTime = Self.nonBlank(startTime)
        self.endTime = Self.nonBlank(endTime)
        self.languages = Self.cleanList(languages)
        self.tags = Self.cleanList(tags)
        self.library = Self.nonBlank(library)
        self.role = Self.nonBlank(role)
        self.skills = Self.cleanList(skills)
        self.type = Self.nonBlank(type)
        self.questions = Self.cleanList(questions)
        self.shuffleQuestions = shuffleQuestions
        self.enableProctoring = enableProctoring
    }

    private static func cleanList(_ values: [String]?) -> [String]? {
        let cleaned = values?.compactMap(nonBlank)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// The test echoed back by a successful create/update/delete. All-optional so a 2xx
/// never fails to decode on an unexpected shape.
public nonisolated struct CreatedTest: Decodable, Sendable {
    public let id: String?
    public let name: String?
}

/// The body sent when creating a team.
nonisolated struct CreateTeamRequest: Encodable {
    let name: String
}

/// The body sent when adding a team member. Snake-case to match the API; a blank role
/// is omitted.
nonisolated struct AddTeamMemberRequest: Encodable {
    let email: String
    let role: String?
}

/// An empty JSON body (`{}`) for a write whose parameters are all in the path — a team-member
/// removal identifies the user in the URL.
nonisolated struct EmptyBody: Encodable {}

/// The team echoed back by a successful create. All-optional so a 2xx never fails to
/// decode on an unexpected shape.
public nonisolated struct CreatedTeam: Decodable, Sendable {
    public let id: String?
    public let name: String?
}

/// The record echoed back by a team-membership change. All-optional for the same
/// reason as the other write echoes.
public nonisolated struct TeamMembershipResult: Decodable, Sendable {
    public let id: String?
    public let email: String?
}

/// The body sent when creating a QuickPad interview.
nonisolated struct CreateQuickPadRequest: Encodable {
    let title: String?
    let quickpad: Bool
}

/// The body sent when scheduling an interview. The start time is an ISO-8601 string;
/// blank optional fields are omitted.
nonisolated struct ScheduleInterviewRequest: Encodable {
    let title: String
    let from: String
    let candidate: String?
    let notes: String?
}

/// The interview echoed back by a successful create. All-optional so a 2xx never fails
/// to decode on an unexpected shape; the URL lets a client open the new pad.
public nonisolated struct CreatedInterview: Decodable, Sendable {
    public let id: String?
    public let url: String?
    public let status: String?
}
