//
//  InterviewTemplates.swift
//  HackerRankKit
//
//  The interview-template resource and its create/update bodies. Create and update take
//  deliberately different option types: the two endpoints accept different fields, and one
//  shared type could only offer each of them properties the other ignores.
//

import Foundation

/// An interview template (`InterviewTemplateIndex`/`InterviewTemplateShow`).
public nonisolated struct InterviewTemplate: Decodable, Hashable, Identifiable, Sendable {
    /// The template's identifier.
    public let id: Int?
    /// The template's name.
    public let name: String?
    /// ISO-8601 creation timestamp.
    public let createdAt: String?
    /// The template's status: 0 deleted, 1 active.
    public let status: Int?
    /// Identifier of the user who created the template.
    public let user: Int?
    /// Unique ids of the roles the template is associated with.
    public let roles: [String]?
    /// Legacy team sharing permission level: 0 none, 1 read, 2 write, 3 delete.
    ///
    /// The server still sends this, but it no longer controls anything: HackerRank
    /// deprecated the field and the write endpoints ignore it. Read a template's real
    /// access from ``editorAccess``, and change it with
    /// ``HackerRankClient/shareInterviewTemplate(id:grants:)``.
    public let teamShare: Int?
    /// Identifiers of the questions in the template.
    public let questions: [String]?
    /// Identifier of the scorecard attached to the template.
    public let scorecard: Int?
    /// Whether every question in the template can be imported at once.
    public let importTemplate: Bool?
    /// Whether the current user may edit the template.
    public let editorAccess: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case status
        case user
        case roles
        case teamShare = "team_share"
        case questions
        case scorecard
        case importTemplate = "import_template"
        case editorAccess = "editor_access"
    }

    public init(
        id: Int? = nil,
        name: String? = nil,
        createdAt: String? = nil,
        status: Int? = nil,
        user: Int? = nil,
        roles: [String]? = nil,
        teamShare: Int? = nil,
        questions: [String]? = nil,
        scorecard: Int? = nil,
        importTemplate: Bool? = nil,
        editorAccess: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.status = status
        self.user = user
        self.roles = roles
        self.teamShare = teamShare
        self.questions = questions
        self.scorecard = scorecard
        self.importTemplate = importTemplate
        self.editorAccess = editorAccess
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.loggedDecodeIfPresent(Int.self, forKey: .id)
        name = container.loggedDecodeIfPresent(String.self, forKey: .name)
        createdAt = container.loggedDecodeIfPresent(String.self, forKey: .createdAt)
        status = container.loggedDecodeIfPresent(Int.self, forKey: .status)
        user = container.loggedDecodeIfPresent(Int.self, forKey: .user)
        roles = container.loggedDecodeIfPresent([String].self, forKey: .roles)
        teamShare = container.loggedDecodeIfPresent(Int.self, forKey: .teamShare)
        questions = container.loggedDecodeIfPresent([String].self, forKey: .questions)
        scorecard = container.loggedDecodeIfPresent(Int.self, forKey: .scorecard)
        importTemplate = container.loggedDecodeIfPresent(Bool.self, forKey: .importTemplate)
        editorAccess = container.loggedDecodeIfPresent(Bool.self, forKey: .editorAccess)
    }
}

/// The ownership views the interview-template list can be narrowed to server-side.
public nonisolated enum InterviewTemplateFilter: String, CaseIterable, Sendable {
    /// Templates the current user created.
    case owned
    /// Templates shared with the current user, excluding their own.
    case shared
}

/// The acknowledgement returned by a successful interview-template delete, which is a
/// message and nothing else.
public nonisolated struct InterviewTemplateWriteResult: Decodable, Sendable {
    public let message: String?
}

/// The body sent when creating an interview template.
nonisolated struct CreateInterviewTemplateRequest: Encodable {
    let name: String
    let options: InterviewTemplateCreateOptions

    enum CodingKeys: String, CodingKey {
        case name
        case roleID = "role_id"
        case questionIDs = "question_ids"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(options.roleID, forKey: .roleID)
        try container.encodeIfPresent(options.questionIDs, forKey: .questionIDs)
    }
}

/// Optional fields for creating an interview template.
///
/// There is no sharing field here: `team_share` is deprecated and ignored, so share a
/// template after creating it with ``HackerRankClient/shareInterviewTemplate(id:grants:)``.
public nonisolated struct InterviewTemplateCreateOptions: Sendable, Equatable {
    /// Unique id of the role the template targets.
    public let roleID: String?
    /// Identifiers of the questions to add to the template. These are **integers** on the
    /// create endpoint, under `question_ids`.
    public let questionIDs: [Int]?

    public init(roleID: String? = nil, questionIDs: [Int]? = nil) {
        let trimmedRole = roleID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.roleID = trimmedRole?.isEmpty == false ? trimmedRole : nil
        self.questionIDs = questionIDs
    }
}

/// The body sent when updating an interview template. Only the fields supplied are sent;
/// the server leaves everything else unchanged.
nonisolated struct UpdateInterviewTemplateRequest: Encodable {
    let options: InterviewTemplateUpdateOptions

    enum CodingKeys: String, CodingKey {
        case name
        case roleID = "role_id"
        case scorecardID = "scorecard_id"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.name, forKey: .name)
        try container.encodeIfPresent(options.roleID, forKey: .roleID)
        try container.encodeIfPresent(options.scorecardID, forKey: .scorecardID)
    }
}

/// Optional fields for updating an interview template.
///
/// The update endpoint accepts neither `questions` nor `question_ids`: a template's
/// question list is set when it is created, and offering to change it here would promise
/// something the server does not do. Sharing is not here either — `team_share` is
/// deprecated and ignored; use ``HackerRankClient/shareInterviewTemplate(id:grants:)``.
public nonisolated struct InterviewTemplateUpdateOptions: Sendable, Equatable {
    /// The template's name.
    public let name: String?
    /// Unique id of the role the template targets.
    public let roleID: String?
    /// Identifier of the scorecard to attach to the template.
    public let scorecardID: Int?

    public init(name: String? = nil, roleID: String? = nil, scorecardID: Int? = nil) {
        self.name = Self.nonBlank(name)
        self.roleID = Self.nonBlank(roleID)
        self.scorecardID = scorecardID
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

// MARK: - Explicit sharing

/// Who an interview template's access is granted to or revoked from — the `rollable` of
/// an `ExplicitSharingRoleGrant`.
///
/// Team ids come from ``HackerRankClient/teamsPage(after:)`` and user ids from
/// ``HackerRankClient/usersPage(after:)``. ``company`` shares with the whole
/// organisation and names no id.
public nonisolated enum InterviewTemplateShareTarget: Hashable, Sendable {
    /// One person.
    case user(id: String)
    /// Everyone on a team.
    case team(id: String)
    /// Everyone in the organisation.
    case company

    /// The `rollable_type` the API names this target by.
    var rollableType: String {
        switch self {
        case .user: "user"
        case .team: "team"
        case .company: "company"
        }
    }

    /// The `rollable_id`, which a whole-company grant does not carry.
    var rollableID: String? {
        switch self {
        case let .user(id), let .team(id): id
        case .company: nil
        }
    }
}

/// The access an explicit sharing grant carries.
public nonisolated enum InterviewTemplateShareRole: String, CaseIterable, Sendable {
    /// May open the template but not change it.
    case viewer
    /// May open and edit the template.
    case editor
}

/// One sharing grant: who to share a template with, and with what access.
public nonisolated struct InterviewTemplateShareGrant: Hashable, Sendable {
    /// The person, team, or company being granted access.
    public let target: InterviewTemplateShareTarget
    /// The access they are granted.
    public let role: InterviewTemplateShareRole

    public init(target: InterviewTemplateShareTarget, role: InterviewTemplateShareRole) {
        self.target = target
        self.role = role
    }
}

/// The acknowledgement returned by a sharing change.
///
/// The revoke endpoint documents no response body at all and the grant endpoint's `model`
/// is documented only as an empty array, so every field here is optional: the call
/// succeeding is the result, and these are what the server chose to say about it.
public nonisolated struct InterviewTemplateSharingResult: Decodable, Sendable {
    /// Whether the server reports the roles were applied.
    public let status: Bool?
    /// The server's message, e.g. `"Successfully updated"`.
    public let message: String?
}

/// One entry of `explicit_roles`: an `ExplicitSharingRoleGrant` when it carries a role, an
/// `ExplicitSharingRoleRevoke` when it does not.
nonisolated struct InterviewTemplateSharingEntry: Encodable {
    let target: InterviewTemplateShareTarget
    let role: InterviewTemplateShareRole?

    enum CodingKeys: String, CodingKey {
        case rollableType = "rollable_type"
        case rollableID = "rollable_id"
        case roleName = "role_name"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(target.rollableType, forKey: .rollableType)
        // The schema documents `rollable_id` as an integer, while the ids the team and
        // user lists hand out are opaque strings. A numeric id is sent as a number and
        // anything else as the string it is, rather than mangling one into the other.
        if let id = target.rollableID {
            if let numeric = Int(id) {
                try container.encode(numeric, forKey: .rollableID)
            } else {
                try container.encode(id, forKey: .rollableID)
            }
        }
        try container.encodeIfPresent(role?.rawValue, forKey: .roleName)
    }
}

/// The body sent to the explicit-sharing endpoints: `explicit_roles`, one entry per
/// target. Grants name a `role_name`; revocations do not.
nonisolated struct InterviewTemplateSharingRequest: Encodable {
    let entries: [InterviewTemplateSharingEntry]

    enum CodingKeys: String, CodingKey {
        case explicitRoles = "explicit_roles"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .explicitRoles)
    }
}
