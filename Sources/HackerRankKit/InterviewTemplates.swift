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
    /// Team sharing permission level: 0 none, 1 read, 2 write, 3 delete.
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
        case teamShare = "team_share"
        case questionIDs = "question_ids"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(options.roleID, forKey: .roleID)
        try container.encodeIfPresent(options.teamShare, forKey: .teamShare)
        try container.encodeIfPresent(options.questionIDs, forKey: .questionIDs)
    }
}

/// Optional fields for creating an interview template.
public nonisolated struct InterviewTemplateCreateOptions: Sendable, Equatable {
    /// Unique id of the role the template targets.
    public let roleID: String?
    /// Team sharing permission level: 0 none, 1 read, 2 write, 3 delete. The server
    /// defaults to 1 (read) when this is omitted.
    public let teamShare: Int?
    /// Identifiers of the questions to add to the template. These are **integers** on the
    /// create endpoint, under `question_ids`.
    public let questionIDs: [Int]?

    public init(roleID: String? = nil, teamShare: Int? = nil, questionIDs: [Int]? = nil) {
        let trimmedRole = roleID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.roleID = trimmedRole?.isEmpty == false ? trimmedRole : nil
        self.teamShare = teamShare
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
        case teamShare = "team_share"
        case scorecardID = "scorecard_id"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.name, forKey: .name)
        try container.encodeIfPresent(options.roleID, forKey: .roleID)
        try container.encodeIfPresent(options.teamShare, forKey: .teamShare)
        try container.encodeIfPresent(options.scorecardID, forKey: .scorecardID)
    }
}

/// Optional fields for updating an interview template.
///
/// The update endpoint accepts neither `questions` nor `question_ids`: a template's
/// question list is set when it is created, and offering to change it here would promise
/// something the server does not do.
public nonisolated struct InterviewTemplateUpdateOptions: Sendable, Equatable {
    /// The template's name.
    public let name: String?
    /// Unique id of the role the template targets.
    public let roleID: String?
    /// Team sharing permission level: 0 none, 1 read, 2 write, 3 delete.
    public let teamShare: Int?
    /// Identifier of the scorecard to attach to the template.
    public let scorecardID: Int?

    public init(name: String? = nil, roleID: String? = nil, teamShare: Int? = nil, scorecardID: Int? = nil) {
        self.name = Self.nonBlank(name)
        self.roleID = Self.nonBlank(roleID)
        self.teamShare = teamShare
        self.scorecardID = scorecardID
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}
