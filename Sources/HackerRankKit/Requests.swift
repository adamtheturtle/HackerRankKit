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
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: HackerRankJSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([HackerRankJSONValue].self))
        }
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

/// A SCIM list response from the legacy `/Users` and `/Groups` provisioning endpoints.
public nonisolated struct SCIMListResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    public let resources: [Item]
    public let totalResults: Int?
    public let startIndex: Int?
    public let itemsPerPage: Int?

    enum CodingKeys: String, CodingKey {
        case resources = "Resources"
        case totalResults
        case startIndex
        case itemsPerPage
        case data
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decoded **leniently**, like `HackerRankPage`: the `try?` has to sit inside the array
        // so a single malformed row (a numeric `id` where `SCIMUser.id` is a `String?`, say) is
        // dropped on its own. Wrapping the whole array instead discards every good row too, so
        // a fully populated directory silently reads as empty.
        resources = (try? container.decode([LenientElement<Item>].self, forKey: .resources))?.compactMap(\.value)
            ?? ((try? container.decode([LenientElement<Item>].self, forKey: .data))?.compactMap(\.value) ?? [])
        totalResults = try? container.decodeIfPresent(Int.self, forKey: .totalResults)
        startIndex = try? container.decodeIfPresent(Int.self, forKey: .startIndex)
        itemsPerPage = try? container.decodeIfPresent(Int.self, forKey: .itemsPerPage)
    }
}

/// A user from the legacy SCIM `/Users` provisioning endpoints.
public nonisolated struct SCIMUser: Decodable, Identifiable, Sendable {
    public let id: String?
    public let userName: String?
    public let active: Bool?
    public let role: String?
    public let teamAdmin: Bool?
    public let companyAdmin: Bool?
    public let name: [String: HackerRankJSONValue]?
    public let emails: [HackerRankJSONValue]?
    public let schemas: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case userName
        case active
        case role
        case teamAdmin = "team_admin"
        case companyAdmin = "company_admin"
        case name
        case emails
        case schemas
    }
}

/// A group/team from the legacy SCIM `/Groups` provisioning endpoints.
public nonisolated struct SCIMGroup: Decodable, Identifiable, Sendable {
    public let id: String?
    public let displayName: String?
    public let members: [HackerRankJSONValue]?
    public let schemas: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case misspelledDisplayName = "diplayName"
        case members
        case schemas
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(String.self, forKey: .id)
        displayName = (try? container.decodeIfPresent(String.self, forKey: .displayName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .misspelledDisplayName))
        members = try? container.decodeIfPresent([HackerRankJSONValue].self, forKey: .members)
        schemas = try? container.decodeIfPresent([String].self, forKey: .schemas)
    }
}

/// The body sent when creating or replacing a legacy SCIM user.
public nonisolated struct SCIMUserWriteRequest: Encodable, Sendable, Equatable {
    public let userName: String?
    public let active: Bool?
    public let role: String?
    public let teamAdmin: Bool?
    public let companyAdmin: Bool?
    public let name: [String: HackerRankJSONValue]?
    public let emails: [HackerRankJSONValue]?
    public let schemas: [String]?

    enum CodingKeys: String, CodingKey {
        case userName
        case active
        case role
        case teamAdmin = "team_admin"
        case companyAdmin = "company_admin"
        case name
        case emails
        case schemas
    }

    public init(
        userName: String? = nil,
        active: Bool? = nil,
        role: String? = nil,
        teamAdmin: Bool? = nil,
        companyAdmin: Bool? = nil,
        name: [String: HackerRankJSONValue]? = nil,
        emails: [HackerRankJSONValue]? = nil,
        schemas: [String]? = nil
    ) {
        self.userName = Self.nonBlank(userName)
        self.active = active
        self.role = Self.nonBlank(role)
        self.teamAdmin = teamAdmin
        self.companyAdmin = companyAdmin
        self.name = name?.isEmpty == false ? name : nil
        self.emails = emails?.isEmpty == false ? emails : nil
        self.schemas = Self.cleanList(schemas)
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

/// The body sent when creating or replacing a legacy SCIM group.
public nonisolated struct SCIMGroupWriteRequest: Encodable, Sendable, Equatable {
    public let displayName: String?
    public let members: [HackerRankJSONValue]?
    public let schemas: [String]?

    public init(
        displayName: String? = nil,
        members: [HackerRankJSONValue]? = nil,
        schemas: [String]? = nil
    ) {
        self.displayName = Self.nonBlank(displayName)
        self.members = members?.isEmpty == false ? members : nil
        self.schemas = Self.cleanList(schemas)
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

/// The body sent for legacy SCIM PATCH operations.
public nonisolated struct SCIMPatchRequest: Encodable, Sendable, Equatable {
    public let schemas: [String]?
    public let operations: [SCIMPatchOperation]

    enum CodingKeys: String, CodingKey {
        case schemas
        case operations = "Operations"
    }

    public init(
        operations: [SCIMPatchOperation],
        schemas: [String]? = ["urn:ietf:params:scim:api:messages:2.0:PatchOp"]
    ) {
        self.operations = operations
        self.schemas = schemas?.isEmpty == false ? schemas : nil
    }
}

/// One operation in a legacy SCIM PATCH request.
public nonisolated struct SCIMPatchOperation: Encodable, Sendable, Equatable {
    public let op: String
    public let path: String?
    public let value: HackerRankJSONValue?

    public init(op: String, path: String? = nil, value: HackerRankJSONValue? = nil) {
        self.op = op.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = path?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.path = trimmedPath?.isEmpty == false ? trimmedPath : nil
        self.value = value
    }
}

/// Authentication for a candidate result webhook (the schema's `WebhookAuthentication`).
///
/// HackerRank requires this whenever a result URL is supplied, so a webhook is never
/// configured without a way for the receiver to verify the caller.
public nonisolated struct WebhookAuthentication: Sendable, Equatable, Encodable {
    /// The authentication scheme, e.g. `bearer_token` or `basic_auth`.
    public let type: String
    /// The scheme's data — `{"token": "..."}` for `bearer_token`,
    /// `{"username": "...", "password": "..."}` for `basic_auth`.
    public let data: [String: HackerRankJSONValue]

    public init(type: String, data: [String: HackerRankJSONValue]) {
        self.type = type.trimmingCharacters(in: .whitespacesAndNewlines)
        self.data = data
    }

    /// Bearer-token authentication, the common case.
    public static func bearerToken(_ token: String) -> Self {
        Self(type: "bearer_token", data: ["token": .string(token)])
    }

    /// HTTP basic authentication.
    public static func basicAuth(username: String, password: String) -> Self {
        Self(type: "basic_auth", data: ["username": .string(username), "password": .string(password)])
    }
}

/// Accessibility accommodations granted to a candidate (the schema's
/// `CandidateAccommodations`).
///
/// Additional time is expressed as a **percentage of the test's duration**, not as a
/// number of minutes: the same accommodation then means the same thing on a 30-minute
/// screen and a 3-hour take-home.
public nonisolated struct CandidateAccommodations: Sendable, Equatable, Encodable {
    /// Extra time as a percentage of the test duration. The API requires a value above 0.
    public let additionalTimePercent: Int?

    enum CodingKeys: String, CodingKey {
        case additionalTimePercent = "additional_time_percent"
    }

    public init(additionalTimePercent: Int? = nil) {
        self.additionalTimePercent = additionalTimePercent
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
        case inviteValidFrom = "invite_valid_from"
        case inviteValidTo = "invite_valid_to"
        case subject
        case message
        case template
        case evaluatorEmail = "evaluator_email"
        case testFinishURL = "test_finish_url"
        case testResultURL = "test_result_url"
        case webhookAuthentication = "webhook_authentication"
        case acceptResultUpdates = "accept_result_updates"
        case tags
        case force
        case forceReattempt = "force_reattempt"
        case accommodations
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(fullName, forKey: .fullName)
        try container.encode(sendEmail, forKey: .sendEmail)
        try container.encodeIfPresent(options.inviteValidFrom, forKey: .inviteValidFrom)
        try container.encodeIfPresent(options.inviteValidTo, forKey: .inviteValidTo)
        try container.encodeIfPresent(options.subject, forKey: .subject)
        try container.encodeIfPresent(options.message, forKey: .message)
        try container.encodeIfPresent(options.template, forKey: .template)
        try container.encodeIfPresent(options.evaluatorEmail, forKey: .evaluatorEmail)
        try container.encodeIfPresent(options.testFinishURL, forKey: .testFinishURL)
        try container.encodeIfPresent(options.testResultURL, forKey: .testResultURL)
        try container.encodeIfPresent(options.webhookAuthentication, forKey: .webhookAuthentication)
        try container.encodeIfPresent(options.acceptResultUpdates, forKey: .acceptResultUpdates)
        try container.encodeIfPresent(options.tags, forKey: .tags)
        try container.encodeIfPresent(options.force, forKey: .force)
        try container.encodeIfPresent(options.forceReattempt, forKey: .forceReattempt)
        try container.encodeIfPresent(options.accommodations, forKey: .accommodations)
    }
}

/// Optional fields for a candidate invite. Values are omitted from the request when unset,
/// so callers can opt into richer API support without changing the minimal invite path.
///
/// Every field here is one the `TestCandidateCreate` schema defines. Options that named a
/// key the schema does not have looked like they configured an invite while the server
/// ignored them.
public nonisolated struct CandidateInviteOptions: Sendable, Equatable {
    /// ISO-8601 time before which the invite should not be usable.
    public let inviteValidFrom: String?
    /// ISO-8601 time after which the invite should expire.
    public let inviteValidTo: String?
    /// Subject of the invitation email.
    public let subject: String?
    /// Custom message prepended to the invitation email body.
    public let message: String?
    /// Identifier of the invitation template to use.
    public let template: String?
    /// Evaluator email address assigned to the invite.
    public let evaluatorEmail: String?
    /// URL the candidate is redirected to after finishing the test.
    public let testFinishURL: String?
    /// Webhook URL the candidate's report is posted to.
    public let testResultURL: String?
    /// Authentication for ``testResultURL``. The API requires it whenever a result URL is
    /// set, so an invite that configures the webhook must configure this too.
    public let webhookAuthentication: WebhookAuthentication?
    /// Whether score and status updates are sent to ``testResultURL``.
    public let acceptResultUpdates: Bool?
    /// Tags to attach to the candidate invite.
    public let tags: [String]?
    /// Whether to email a candidate who has already been invited.
    public let force: Bool?
    /// Whether to re-invite a candidate who has already attempted the test.
    public let forceReattempt: Bool?
    /// Accessibility accommodations for the candidate.
    public let accommodations: CandidateAccommodations?

    public init(
        inviteValidFrom: String? = nil,
        inviteValidTo: String? = nil,
        subject: String? = nil,
        message: String? = nil,
        template: String? = nil,
        evaluatorEmail: String? = nil,
        testFinishURL: String? = nil,
        testResultURL: String? = nil,
        webhookAuthentication: WebhookAuthentication? = nil,
        acceptResultUpdates: Bool? = nil,
        tags: [String]? = nil,
        force: Bool? = nil,
        forceReattempt: Bool? = nil,
        accommodations: CandidateAccommodations? = nil
    ) {
        self.inviteValidFrom = Self.nonBlank(inviteValidFrom)
        self.inviteValidTo = Self.nonBlank(inviteValidTo)
        self.subject = Self.nonBlank(subject)
        self.message = Self.nonBlank(message)
        self.template = Self.nonBlank(template)
        self.evaluatorEmail = Self.nonBlank(evaluatorEmail)
        self.testFinishURL = Self.nonBlank(testFinishURL)
        self.testResultURL = Self.nonBlank(testResultURL)
        self.webhookAuthentication = webhookAuthentication
        self.acceptResultUpdates = acceptResultUpdates
        let cleanedTags = tags?.compactMap(Self.nonBlank)
        self.tags = cleanedTags?.isEmpty == false ? cleanedTags : nil
        self.force = force
        self.forceReattempt = forceReattempt
        self.accommodations = accommodations
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
        // nil means "do not update tags"; an explicit empty array means "clear all
        // tags" and must survive through encodeIfPresent.
        self.tags = tags.map { $0.compactMap(Self.nonBlank) }
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
        // These optional profile fields support clearing. Preserve an explicitly
        // supplied empty value while nil continues to mean "leave unchanged".
        self.lastName = lastName.map(Self.trimmed)
        self.country = country.map(Self.trimmed)
        self.role = Self.nonBlank(role)
        self.phone = phone.map(Self.trimmed)
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

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
    if options.clearsRecommendedDuration {
        try container.encodeNil(forKey: .recommendedDuration)
    } else {
        try container.encodeIfPresent(options.recommendedDuration, forKey: .recommendedDuration)
    }
    try container.encodeIfPresent(options.tags, forKey: .tags)
    if options.clearsMaxScore {
        try container.encodeNil(forKey: .maxScore)
    } else {
        try container.encodeIfPresent(options.maxScore, forKey: .maxScore)
    }
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
    /// Whether an update explicitly clears the optional duration with JSON null.
    public let clearsRecommendedDuration: Bool
    /// Tags to attach to the question.
    public let tags: [String]?
    /// Maximum achievable score.
    public let maxScore: Double?
    /// Whether an update explicitly clears the optional score with JSON null.
    public let clearsMaxScore: Bool
    /// Skills assessed by the question.
    public let skills: [String]?

    public init(
        status: String? = nil,
        languages: [String]? = nil,
        problemStatement: String? = nil,
        recommendedDuration: Int? = nil,
        tags: [String]? = nil,
        maxScore: Double? = nil,
        skills: [String]? = nil,
        clearsRecommendedDuration: Bool = false,
        clearsMaxScore: Bool = false
    ) {
        self.status = Self.nonBlank(status)
        self.languages = Self.cleanList(languages)
        self.problemStatement = Self.nonBlank(problemStatement)
        self.recommendedDuration = recommendedDuration
        self.clearsRecommendedDuration = clearsRecommendedDuration
        self.tags = Self.cleanList(tags)
        self.maxScore = maxScore
        self.clearsMaxScore = clearsMaxScore
        self.skills = Self.cleanList(skills)
    }

    private static func cleanList(_ values: [String]?) -> [String]? {
        guard let values else { return nil }
        return values.compactMap(nonBlank)
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

/// A lightweight acknowledgement for question codestub and testcase operations.
public nonisolated struct QuestionOperationResult: Decodable, Sendable {
    public let id: String?
    public let status: String?
    public let message: String?
}

/// The body sent when updating custom code stubs for a coding question.
nonisolated struct CustomCodeStubsRequest: Encodable {
    let stubs: [QuestionCodeStub]

    enum CodingKeys: String, CodingKey {
        case stubs = "custom_codestubs"
    }
}

/// One language-specific custom code stub for a coding question.
public nonisolated struct QuestionCodeStub: Sendable, Equatable, Encodable {
    public let language: String
    public let code: String

    public init(language: String, code: String) {
        self.language = language.trimmingCharacters(in: .whitespacesAndNewlines)
        self.code = code
    }
}

/// The body sent when asking HackerRank to generate code stubs for a coding question.
nonisolated struct GenerateCodeStubsRequest: Encodable {
    let options: CodeStubGenerationOptions

    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
        case returnType = "return_type"
        case parameters
        case languages
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.functionName, forKey: .functionName)
        try container.encodeIfPresent(options.returnType, forKey: .returnType)
        try container.encodeIfPresent(options.parameters, forKey: .parameters)
        try container.encodeIfPresent(options.languages, forKey: .languages)
    }
}

/// Optional fields for code-stub generation. The API uses function-signature metadata
/// and an optional language list; unset values are omitted.
public nonisolated struct CodeStubGenerationOptions: Sendable, Equatable {
    public let functionName: String?
    public let returnType: String?
    public let parameters: [CodeStubParameter]?
    public let languages: [String]?

    public init(
        functionName: String? = nil,
        returnType: String? = nil,
        parameters: [CodeStubParameter]? = nil,
        languages: [String]? = nil
    ) {
        self.functionName = Self.nonBlank(functionName)
        self.returnType = Self.nonBlank(returnType)
        self.parameters = parameters?.isEmpty == false ? parameters : nil
        self.languages = Self.cleanList(languages)
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

/// One parameter in a generated function signature.
public nonisolated struct CodeStubParameter: Sendable, Equatable, Encodable {
    public let name: String
    public let type: String

    public init(name: String, type: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The body sent when adding or updating a question testcase.
nonisolated struct QuestionTestcaseRequest: Encodable {
    let options: QuestionTestcaseOptions

    enum CodingKeys: String, CodingKey {
        case explanation
        case input
        case output
        case name
        case qid
        case sample
        case score
        case type
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.explanation, forKey: .explanation)
        try container.encodeIfPresent(options.input, forKey: .input)
        try container.encodeIfPresent(options.output, forKey: .output)
        try container.encodeIfPresent(options.name, forKey: .name)
        try container.encodeIfPresent(options.qid, forKey: .qid)
        try container.encodeIfPresent(options.sample, forKey: .sample)
        try container.encodeIfPresent(options.score, forKey: .score)
        try container.encodeIfPresent(options.type, forKey: .type)
    }
}

/// Optional fields for a coding-question testcase. These match the public API sample;
/// unset string values are omitted, but an intentionally empty explanation is preserved.
public nonisolated struct QuestionTestcaseOptions: Sendable, Equatable {
    public let explanation: String?
    public let input: String?
    public let output: String?
    public let name: String?
    public let qid: Int?
    public let sample: Bool?
    public let score: Int?
    public let type: String?

    public init(
        explanation: String? = nil,
        input: String? = nil,
        output: String? = nil,
        name: String? = nil,
        qid: Int? = nil,
        sample: Bool? = nil,
        score: Int? = nil,
        type: String? = nil
    ) {
        self.explanation = explanation
        self.input = Self.nonBlank(input)
        self.output = Self.nonBlank(output)
        self.name = Self.nonBlank(name)
        self.qid = qid
        self.sample = sample
        self.score = score
        self.type = Self.nonBlank(type)
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// The body sent when creating a test.
///
/// `TestsCreate` requires `name`, `duration`, `role_ids`, and `experience`, so those four
/// are stored separately from the optional ``TestWriteOptions`` and always encoded.
nonisolated struct CreateTestRequest: Encodable {
    let name: String
    let duration: Int
    let roleIDs: [String]
    let experience: [String]
    let options: TestWriteOptions
}

/// The body sent when updating a test. Every field beyond the name is optional here: an
/// update sends only what should change.
nonisolated struct UpdateTestRequest: Encodable {
    let name: String
    let options: TestWriteOptions
}

/// The wire keys shared by the assessment create and update bodies. Only fields defined by
/// the official `TestsCreate`/`TestsUpdate` schemas appear: an option the server does not
/// accept would be silently dropped while the caller believed it applied.
private enum TestWriteCodingKeys: String, CodingKey {
    case name
    case duration
    case cutoffScore = "cutoff_score"
    case instructions
    case startTime = "starttime"
    case endTime = "endtime"
    case languages
    case tags
    case roleIDs = "role_ids"
    case experience
    case questions
    case shuffleQuestions = "shuffle_questions"
    case enableProctoring = "enable_proctoring"
}

extension CreateTestRequest {
    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: TestWriteCodingKeys.self)
        try container.encode(duration, forKey: .duration)
        try container.encode(roleIDs, forKey: .roleIDs)
        try container.encode(experience, forKey: .experience)
        try encodeTestWriteBody(to: &container, name: name, options: options, skippingRequired: true)
    }
}

extension UpdateTestRequest {
    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: TestWriteCodingKeys.self)
        try encodeTestWriteBody(to: &container, name: name, options: options, skippingRequired: false)
    }
}

/// Encodes the name plus whichever options are set. `skippingRequired` omits the three
/// fields a create has already encoded from its own required parameters, so an option
/// value can never contradict the one the caller passed explicitly.
private nonisolated func encodeTestWriteBody(
    to container: inout KeyedEncodingContainer<TestWriteCodingKeys>,
    name: String,
    options: TestWriteOptions,
    skippingRequired: Bool
) throws {
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(options.cutoffScore, forKey: .cutoffScore)
    try container.encodeIfPresent(options.instructions, forKey: .instructions)
    try container.encodeIfPresent(options.startTime, forKey: .startTime)
    try container.encodeIfPresent(options.endTime, forKey: .endTime)
    try container.encodeIfPresent(options.languages, forKey: .languages)
    try container.encodeIfPresent(options.tags, forKey: .tags)
    try container.encodeIfPresent(options.questions, forKey: .questions)
    try container.encodeIfPresent(options.shuffleQuestions, forKey: .shuffleQuestions)
    try container.encodeIfPresent(options.enableProctoring, forKey: .enableProctoring)
    guard !skippingRequired else { return }

    try container.encodeIfPresent(options.duration, forKey: .duration)
    try container.encodeIfPresent(options.roleIDs, forKey: .roleIDs)
    try container.encodeIfPresent(options.experience, forKey: .experience)
}

/// Optional fields for creating or updating an assessment. Values are omitted when unset,
/// so an update sends only what should change.
///
/// Only fields the official `TestsCreate`/`TestsUpdate` schemas define are modelled. The
/// assessment `library`, `skills`, and `type` values a response may carry are **not**
/// writable and are deliberately absent here.
public nonisolated struct TestWriteOptions: Sendable, Equatable {
    /// Duration of the assessment in minutes. Required on a create, where
    /// ``HackerRankClient/createTest(name:duration:roleIDs:experience:options:)`` takes it
    /// as its own parameter; set it here to change an existing assessment's duration.
    public let duration: Int?
    /// Passing score threshold.
    public let cutoffScore: Int?
    /// Candidate-facing instructions.
    public let instructions: String?
    /// ISO-8601 assessment window start (the wire key is `starttime`).
    public let startTime: String?
    /// ISO-8601 assessment window end (the wire key is `endtime`).
    public let endTime: String?
    /// Allowed programming languages.
    public let languages: [String]?
    /// Tags to attach to the assessment.
    public let tags: [String]?
    /// Identifiers of the hiring roles the assessment targets. Required on a create.
    public let roleIDs: [String]?
    /// Experience levels the assessment targets. Required on a create.
    public let experience: [String]?
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
        roleIDs: [String]? = nil,
        experience: [String]? = nil,
        questions: [String]? = nil,
        shuffleQuestions: Bool? = nil,
        enableProctoring: Bool? = nil
    ) {
        self.duration = duration
        self.cutoffScore = cutoffScore
        self.instructions = Self.nonBlank(instructions)
        self.startTime = Self.nonBlank(startTime)
        self.endTime = Self.nonBlank(endTime)
        // nil means "leave unchanged"; an explicitly supplied empty collection means
        // "clear this field" on assessment updates.
        self.languages = Self.cleanClearableList(languages)
        self.tags = Self.cleanClearableList(tags)
        self.roleIDs = Self.cleanClearableList(roleIDs)
        self.experience = Self.cleanClearableList(experience)
        self.questions = Self.cleanList(questions)
        self.shuffleQuestions = shuffleQuestions
        self.enableProctoring = enableProctoring
    }

    private static func cleanList(_ values: [String]?) -> [String]? {
        let cleaned = values?.compactMap(nonBlank)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func cleanClearableList(_ values: [String]?) -> [String]? {
        values?.compactMap(nonBlank)
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
        // nil leaves the collection unchanged; an explicit empty array clears it.
        self.locations = locations.map(Self.cleanedList)
        self.departments = departments.map(Self.cleanedList)
    }

    private static func cleanedList(_ values: [String]) -> [String] {
        values.compactMap(nonBlank)
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

/// An interview template returned by the interview-template endpoints.
public nonisolated struct InterviewTemplate: Decodable, Identifiable, Sendable {
    public let id: Int?
    public let name: String?
    public let title: String?
    public let description: String?
}

/// An acknowledgement for interview-template writes that may return only status metadata.
public nonisolated struct InterviewTemplateWriteResult: Decodable, Sendable {
    public let id: Int?
    public let status: String?
    public let message: String?
}

/// An invite template returned by the invite-template endpoints.
public nonisolated struct InviteTemplate: Decodable, Identifiable, Sendable {
    public let id: String?
    public let name: String?
    public let subject: String?
    public let body: String?
    public let access: String?
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

/// The body sent when updating an interview.
nonisolated struct UpdateInterviewRequest: Encodable {
    let options: InterviewUpdateOptions

    enum CodingKeys: String, CodingKey {
        case title
        case from
        case to
        case candidate
        case interviewers
        case notes
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.title, forKey: .title)
        try container.encodeIfPresent(options.from, forKey: .from)
        try container.encodeIfPresent(options.to, forKey: .to)
        try container.encodeIfPresent(options.candidate, forKey: .candidate)
        try container.encodeIfPresent(options.interviewers, forKey: .interviewers)
        try container.encodeIfPresent(options.notes, forKey: .notes)
    }
}

/// Optional fields for updating an interview.
public nonisolated struct InterviewUpdateOptions: Sendable, Equatable {
    public let title: String?
    public let from: String?
    public let to: String?
    public let candidate: String?
    public let interviewers: [String]?
    public let notes: String?

    public init(
        title: String? = nil,
        from: String? = nil,
        to: String? = nil,
        candidate: String? = nil,
        interviewers: [String]? = nil,
        notes: String? = nil
    ) {
        self.title = Self.nonBlank(title)
        self.from = Self.nonBlank(from)
        self.to = Self.nonBlank(to)
        self.candidate = Self.nonBlank(candidate)
        self.interviewers = Self.cleanList(interviewers)
        self.notes = Self.nonBlank(notes)
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

/// The body sent when creating or updating an interview template.
nonisolated struct InterviewTemplateWriteRequest: Encodable {
    let options: InterviewTemplateWriteOptions

    enum CodingKeys: String, CodingKey {
        case name
        case title
        case description
        case questions
        case tags
        case metadata
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.name, forKey: .name)
        try container.encodeIfPresent(options.title, forKey: .title)
        try container.encodeIfPresent(options.description, forKey: .description)
        try container.encodeIfPresent(options.questions, forKey: .questions)
        try container.encodeIfPresent(options.tags, forKey: .tags)
        try container.encodeIfPresent(options.metadata, forKey: .metadata)
    }
}

/// Optional fields for interview-template writes.
public nonisolated struct InterviewTemplateWriteOptions: Sendable, Equatable {
    public let name: String?
    public let title: String?
    public let description: String?
    public let questions: [String]?
    public let tags: [String]?
    public let metadata: [String: HackerRankJSONValue]?

    public init(
        name: String? = nil,
        title: String? = nil,
        description: String? = nil,
        questions: [String]? = nil,
        tags: [String]? = nil,
        metadata: [String: HackerRankJSONValue]? = nil
    ) {
        self.name = Self.nonBlank(name)
        // Empty optional text is meaningful for updates: the API uses it to clear an
        // existing value. Keep nil as "not supplied", but preserve an explicit empty
        // string after trimming so callers can express that operation.
        self.title = title.map(Self.trimmed)
        self.description = description.map(Self.trimmed)
        self.questions = Self.cleanList(questions)
        self.tags = Self.cleanList(tags)
        self.metadata = metadata?.isEmpty == false ? metadata : nil
    }

    private static func cleanList(_ values: [String]?) -> [String]? {
        let cleaned = values?.compactMap(nonBlank)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The interview echoed back by a successful create. All-optional so a 2xx never fails
/// to decode on an unexpected shape; the URL lets a client open the new pad.
public nonisolated struct CreatedInterview: Decodable, Sendable {
    public let id: String?
    public let url: String?
    public let status: String?
}

/// The body sent when creating an ATS-backed interview invite.
nonisolated struct ATSCodePairRequest: Encodable {
    let title: String
    let requisitionID: String
    let candidateID: String
    let options: ATSCodePairOptions

    enum CodingKeys: String, CodingKey {
        case title
        case requisitionID = "requisition_id"
        case candidateID = "candidate_id"
        case candidate
        case sendEmail = "send_email"
        case interviewMetadata = "interview_metadata"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(requisitionID, forKey: .requisitionID)
        try container.encode(candidateID, forKey: .candidateID)
        try container.encodeIfPresent(options.candidate, forKey: .candidate)
        try container.encodeIfPresent(options.sendEmail, forKey: .sendEmail)
        try container.encodeIfPresent(options.interviewMetadata, forKey: .interviewMetadata)
    }
}

/// Optional fields for an ATS-backed interview invite.
public nonisolated struct ATSCodePairOptions: Sendable, Equatable {
    public let candidate: [String: HackerRankJSONValue]?
    public let sendEmail: Bool?
    public let interviewMetadata: [String: HackerRankJSONValue]?

    public init(
        candidate: [String: HackerRankJSONValue]? = nil,
        sendEmail: Bool? = nil,
        interviewMetadata: [String: HackerRankJSONValue]? = nil
    ) {
        self.candidate = candidate?.isEmpty == false ? candidate : nil
        self.sendEmail = sendEmail
        self.interviewMetadata = interviewMetadata?.isEmpty == false ? interviewMetadata : nil
    }
}

/// The body sent when creating an ATS-backed code screen invite.
nonisolated struct ATSCodeScreenRequest: Encodable {
    let testID: String
    let requisitionID: String
    let candidateID: String
    let email: String
    let options: ATSCodeScreenOptions

    enum CodingKeys: String, CodingKey {
        case testID = "test_id"
        case requisitionID = "requisition_id"
        case candidateID = "candidate_id"
        case email
        case sendEmail = "send_email"
        case testResultURL = "test_result_url"
        case webhookAuthentication = "webhook_authentication"
        case acceptResultUpdates = "accept_result_updates"
        case force
        case forceReattemptAfter = "force_reattempt_after"
        case accommodations
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(testID, forKey: .testID)
        try container.encode(requisitionID, forKey: .requisitionID)
        try container.encode(candidateID, forKey: .candidateID)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(options.sendEmail, forKey: .sendEmail)
        try container.encodeIfPresent(options.testResultURL, forKey: .testResultURL)
        try container.encodeIfPresent(options.webhookAuthentication, forKey: .webhookAuthentication)
        try container.encodeIfPresent(options.acceptResultUpdates, forKey: .acceptResultUpdates)
        try container.encodeIfPresent(options.force, forKey: .force)
        try container.encodeIfPresent(options.forceReattemptAfter, forKey: .forceReattemptAfter)
        try container.encodeIfPresent(options.accommodations, forKey: .accommodations)
    }
}

/// Optional fields for an ATS-backed code screen invite.
public nonisolated struct ATSCodeScreenOptions: Sendable, Equatable {
    public let sendEmail: Bool?
    public let testResultURL: String?
    public let webhookAuthentication: [String: HackerRankJSONValue]?
    public let acceptResultUpdates: Bool?
    public let force: Bool?
    public let forceReattemptAfter: Int?
    public let accommodations: [String: HackerRankJSONValue]?

    public init(
        sendEmail: Bool? = nil,
        testResultURL: String? = nil,
        webhookAuthentication: [String: HackerRankJSONValue]? = nil,
        acceptResultUpdates: Bool? = nil,
        force: Bool? = nil,
        forceReattemptAfter: Int? = nil,
        accommodations: [String: HackerRankJSONValue]? = nil
    ) {
        self.sendEmail = sendEmail
        self.testResultURL = Self.nonBlank(testResultURL)
        self.webhookAuthentication = webhookAuthentication?.isEmpty == false ? webhookAuthentication : nil
        self.acceptResultUpdates = acceptResultUpdates
        self.force = force
        self.forceReattemptAfter = forceReattemptAfter
        self.accommodations = accommodations?.isEmpty == false ? accommodations : nil
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// The result returned by ATS invite endpoints.
public nonisolated struct ATSInviteResult: Decodable, Sendable {
    public let id: String?
    public let url: String?
    public let status: String?
    public let email: String?
}
