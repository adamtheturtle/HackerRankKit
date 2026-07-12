//
//  Requests.swift
//  HackerRankKit
//

import Foundation

// The request bodies and response echoes for `HackerRankClient`'s write flows.
// The request types are module-internal (only the client builds them); the response
// echoes are public (they are the return types of the client's write methods) and
// all-optional so a 2xx never fails to decode on an unexpected shape.

/// A small JSON value tree for API fields whose schema is documented as a free-form object.
public nonisolated enum HackerRankJSONValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: HackerRankJSONValue])
    case array([HackerRankJSONValue])
    case null

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int.self) { self = .int(value) }
        else if let value = try? container.decode(Double.self) { self = .double(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: HackerRankJSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([HackerRankJSONValue].self)) }
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

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

/// The body sent when updating a candidate. Snake-case to match the API; unset values are omitted.
nonisolated struct UpdateCandidateRequest: Encodable {
    let options: CandidateUpdateOptions

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case atsState = "ats_state"
        case inviteValidFrom = "invite_valid_from"
        case inviteValidTo = "invite_valid_to"
        case inviteMetadata = "invite_metadata"
        case evaluatorEmail = "evaluator_email"
        case testFinishURL = "test_finish_url"
        case testResultURL = "test_result_url"
        case webhookAuthentication = "webhook_authentication"
        case acceptResultUpdates = "accept_result_updates"
        case tags
        case accommodations
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.fullName, forKey: .fullName)
        try container.encodeIfPresent(options.atsState, forKey: .atsState)
        try container.encodeIfPresent(options.inviteValidFrom, forKey: .inviteValidFrom)
        try container.encodeIfPresent(options.inviteValidTo, forKey: .inviteValidTo)
        try container.encodeIfPresent(options.inviteMetadata, forKey: .inviteMetadata)
        try container.encodeIfPresent(options.evaluatorEmail, forKey: .evaluatorEmail)
        try container.encodeIfPresent(options.testFinishURL, forKey: .testFinishURL)
        try container.encodeIfPresent(options.testResultURL, forKey: .testResultURL)
        try container.encodeIfPresent(options.webhookAuthentication, forKey: .webhookAuthentication)
        try container.encodeIfPresent(options.acceptResultUpdates, forKey: .acceptResultUpdates)
        try container.encodeIfPresent(options.tags, forKey: .tags)
        try container.encodeIfPresent(options.accommodations, forKey: .accommodations)
    }
}

/// Optional fields for updating a test candidate.
public nonisolated struct CandidateUpdateOptions: Sendable, Equatable {
    public let fullName: String?
    public let atsState: Int?
    public let inviteValidFrom: String?
    public let inviteValidTo: String?
    public let inviteMetadata: [String: HackerRankJSONValue]?
    public let evaluatorEmail: String?
    public let testFinishURL: String?
    public let testResultURL: String?
    public let webhookAuthentication: [String: HackerRankJSONValue]?
    public let acceptResultUpdates: Bool?
    public let tags: [String]?
    public let accommodations: [String: HackerRankJSONValue]?

    public init(
        fullName: String? = nil,
        atsState: Int? = nil,
        inviteValidFrom: String? = nil,
        inviteValidTo: String? = nil,
        inviteMetadata: [String: HackerRankJSONValue]? = nil,
        evaluatorEmail: String? = nil,
        testFinishURL: String? = nil,
        testResultURL: String? = nil,
        webhookAuthentication: [String: HackerRankJSONValue]? = nil,
        acceptResultUpdates: Bool? = nil,
        tags: [String]? = nil,
        accommodations: [String: HackerRankJSONValue]? = nil
    ) {
        self.fullName = Self.nonBlank(fullName)
        self.atsState = atsState
        self.inviteValidFrom = Self.nonBlank(inviteValidFrom)
        self.inviteValidTo = Self.nonBlank(inviteValidTo)
        self.inviteMetadata = inviteMetadata?.isEmpty == false ? inviteMetadata : nil
        self.evaluatorEmail = Self.nonBlank(evaluatorEmail)
        self.testFinishURL = Self.nonBlank(testFinishURL)
        self.testResultURL = Self.nonBlank(testResultURL)
        self.webhookAuthentication = webhookAuthentication?.isEmpty == false ? webhookAuthentication : nil
        self.acceptResultUpdates = acceptResultUpdates
        let cleanedTags = tags?.compactMap(Self.nonBlank)
        self.tags = cleanedTags?.isEmpty == false ? cleanedTags : nil
        self.accommodations = accommodations?.isEmpty == false ? accommodations : nil
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

/// A candidate write acknowledgement for endpoints that do not return a full candidate.
public nonisolated struct CandidateWriteResult: Decodable, Sendable {
    public let id: String?
    public let email: String?
    public let status: Int?
}

/// The response from the candidate report PDF URL endpoint.
public nonisolated struct CandidateReportPDF: Decodable, Sendable {
    public let url: String?
    public let pdfURL: String?

    enum CodingKeys: String, CodingKey {
        case url
        case pdfURL = "pdf_url"
    }
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

/// The body sent when updating a user.
nonisolated struct UpdateUserRequest: Encodable {
    let options: UserUpdateOptions

    enum CodingKeys: String, CodingKey {
        case firstName = "firstname"
        case lastName = "lastname"
        case country
        case role
        case phone
        case questionsPermission = "questions_permission"
        case testsPermission = "tests_permission"
        case interviewsPermission = "interviews_permission"
        case candidatesPermission = "candidates_permission"
        case sharedQuestionsPermission = "shared_questions_permission"
        case sharedTestsPermission = "shared_tests_permission"
        case sharedInterviewsPermission = "shared_interviews_permission"
        case sharedCandidatesPermission = "shared_candidates_permission"
        case companyAdmin = "company_admin"
        case teamAdmin = "team_admin"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.firstName, forKey: .firstName)
        try container.encodeIfPresent(options.lastName, forKey: .lastName)
        try container.encodeIfPresent(options.country, forKey: .country)
        try container.encodeIfPresent(options.role, forKey: .role)
        try container.encodeIfPresent(options.phone, forKey: .phone)
        try container.encodeIfPresent(options.questionsPermission, forKey: .questionsPermission)
        try container.encodeIfPresent(options.testsPermission, forKey: .testsPermission)
        try container.encodeIfPresent(options.interviewsPermission, forKey: .interviewsPermission)
        try container.encodeIfPresent(options.candidatesPermission, forKey: .candidatesPermission)
        try container.encodeIfPresent(options.sharedQuestionsPermission, forKey: .sharedQuestionsPermission)
        try container.encodeIfPresent(options.sharedTestsPermission, forKey: .sharedTestsPermission)
        try container.encodeIfPresent(options.sharedInterviewsPermission, forKey: .sharedInterviewsPermission)
        try container.encodeIfPresent(options.sharedCandidatesPermission, forKey: .sharedCandidatesPermission)
        try container.encodeIfPresent(options.companyAdmin, forKey: .companyAdmin)
        try container.encodeIfPresent(options.teamAdmin, forKey: .teamAdmin)
    }
}

/// Optional fields for updating a user.
public nonisolated struct UserUpdateOptions: Sendable, Equatable {
    public let firstName: String?
    public let lastName: String?
    public let country: String?
    public let role: String?
    public let phone: String?
    public let questionsPermission: Int?
    public let testsPermission: Int?
    public let interviewsPermission: Int?
    public let candidatesPermission: Int?
    public let sharedQuestionsPermission: Int?
    public let sharedTestsPermission: Int?
    public let sharedInterviewsPermission: Int?
    public let sharedCandidatesPermission: Int?
    public let companyAdmin: Bool?
    public let teamAdmin: Bool?

    public init(
        firstName: String? = nil,
        lastName: String? = nil,
        country: String? = nil,
        role: String? = nil,
        phone: String? = nil,
        questionsPermission: Int? = nil,
        testsPermission: Int? = nil,
        interviewsPermission: Int? = nil,
        candidatesPermission: Int? = nil,
        sharedQuestionsPermission: Int? = nil,
        sharedTestsPermission: Int? = nil,
        sharedInterviewsPermission: Int? = nil,
        sharedCandidatesPermission: Int? = nil,
        companyAdmin: Bool? = nil,
        teamAdmin: Bool? = nil
    ) {
        self.firstName = Self.nonBlank(firstName)
        self.lastName = Self.nonBlank(lastName)
        self.country = Self.nonBlank(country)
        self.role = Self.nonBlank(role)
        self.phone = Self.nonBlank(phone)
        self.questionsPermission = questionsPermission
        self.testsPermission = testsPermission
        self.interviewsPermission = interviewsPermission
        self.candidatesPermission = candidatesPermission
        self.sharedQuestionsPermission = sharedQuestionsPermission
        self.sharedTestsPermission = sharedTestsPermission
        self.sharedInterviewsPermission = sharedInterviewsPermission
        self.sharedCandidatesPermission = sharedCandidatesPermission
        self.companyAdmin = companyAdmin
        self.teamAdmin = teamAdmin
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// A user write acknowledgement for endpoints that do not return a full user.
public nonisolated struct UserWriteResult: Decodable, Sendable {
    public let id: String?
    public let email: String?
    public let status: String?
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

/// The body sent when updating a team.
nonisolated struct UpdateTeamRequest: Encodable {
    let options: TeamUpdateOptions

    enum CodingKeys: String, CodingKey {
        case name
        case recruiterCap = "recruiter_cap"
        case developerCap = "developer_cap"
        case inviteAs = "invite_as"
        case locations
        case departments
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.name, forKey: .name)
        try container.encodeIfPresent(options.recruiterCap, forKey: .recruiterCap)
        try container.encodeIfPresent(options.developerCap, forKey: .developerCap)
        try container.encodeIfPresent(options.inviteAs, forKey: .inviteAs)
        try container.encodeIfPresent(options.locations, forKey: .locations)
        try container.encodeIfPresent(options.departments, forKey: .departments)
    }
}

/// Optional fields for updating a team.
public nonisolated struct TeamUpdateOptions: Sendable, Equatable {
    public let name: String?
    public let recruiterCap: Int?
    public let developerCap: Int?
    public let inviteAs: String?
    public let locations: [String]?
    public let departments: [String]?

    public init(
        name: String? = nil,
        recruiterCap: Int? = nil,
        developerCap: Int? = nil,
        inviteAs: String? = nil,
        locations: [String]? = nil,
        departments: [String]? = nil
    ) {
        self.name = Self.nonBlank(name)
        self.recruiterCap = recruiterCap
        self.developerCap = developerCap
        self.inviteAs = Self.nonBlank(inviteAs)
        self.locations = Self.cleanList(locations)
        self.departments = Self.cleanList(departments)
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
