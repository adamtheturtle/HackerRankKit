//
//  Test.swift
//  HackerRankKit
//

import Foundation

/// A HackerRank for Work test (assessment).
///
/// Fields mirror the HackerRank for Work API's test resource. Only the fields a
/// read-only UI typically needs are modelled; `Decodable` ignores any other keys in the
/// response, so this decodes live responses without failing on unmodelled fields.
///
/// `nonisolated` so the model can be decoded off the main actor by the REST client
/// (the target builds with MainActor default actor isolation).
public nonisolated struct Test: Codable, Hashable, Identifiable, Sendable {
    /// The unique identifier of the test.
    public let id: String
    /// A short, human-shareable identifier for the test.
    public let uniqueID: String?
    /// The test's display name.
    public let name: String
    /// ISO-8601 start time of the test window.
    public let startTime: String?
    /// ISO-8601 end time of the test window.
    public let endTime: String?
    /// Duration of the test in minutes.
    public let duration: Int?
    /// Identifier of the user who owns the test.
    public let owner: String?
    /// Free-text candidate instructions.
    public let instructions: String?
    /// Whether the test is starred by the current user.
    public let starred: Bool?
    /// ISO-8601 creation timestamp.
    public let createdAt: String?
    /// The lifecycle state of the test (e.g. "active", "archived").
    public let state: String?
    /// Whether the test is locked.
    public let locked: Bool?
    /// Whether the test is still a draft.
    public let draft: Bool?
    /// Programming languages allowed in the test.
    public let languages: [String]?
    /// The score at or above which a candidate passes.
    public let cutoffScore: Int?
    /// Tags applied to the test.
    public let tags: [String]?
    /// The source library or collection this test belongs to, when reported by the API.
    public let library: String?
    /// The hiring role or job family this test targets, when reported by the API.
    public let role: String?
    /// Skills assessed by the test, when reported by the API.
    public let skills: [String]?
    /// The test category or assessment type, when reported by the API.
    public let type: String?
    /// Identifiers of the questions in the test.
    public let questions: [String]?
    /// Whether question order is shuffled per candidate.
    public let shuffleQuestions: Bool?
    /// Whether proctoring is enabled for the test.
    public let enableProctoring: Bool?
    /// The test's question sections, when it is organised into them.
    public let sections: [TestSection]?

    enum CodingKeys: String, CodingKey {
        case id
        case uniqueID = "unique_id"
        case name
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case owner
        case instructions
        case starred
        case createdAt = "created_at"
        case state
        case locked
        case draft
        case languages
        case cutoffScore = "cutoff_score"
        case tags
        case library
        case role
        case skills
        case type
        case questions
        case shuffleQuestions = "shuffle_questions"
        case enableProctoring = "enable_proctoring"
        case sections
    }

    public init(
        id: String,
        uniqueID: String? = nil,
        name: String,
        startTime: String? = nil,
        endTime: String? = nil,
        duration: Int? = nil,
        owner: String? = nil,
        instructions: String? = nil,
        starred: Bool? = nil,
        createdAt: String? = nil,
        state: String? = nil,
        locked: Bool? = nil,
        draft: Bool? = nil,
        languages: [String]? = nil,
        cutoffScore: Int? = nil,
        tags: [String]? = nil,
        library: String? = nil,
        role: String? = nil,
        skills: [String]? = nil,
        type: String? = nil,
        questions: [String]? = nil,
        shuffleQuestions: Bool? = nil,
        enableProctoring: Bool? = nil,
        sections: [TestSection]? = nil
    ) {
        self.id = id
        self.uniqueID = uniqueID
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.owner = owner
        self.instructions = instructions
        self.starred = starred
        self.createdAt = createdAt
        self.state = state
        self.locked = locked
        self.draft = draft
        self.languages = languages
        self.cutoffScore = cutoffScore
        self.tags = tags
        self.library = library
        self.role = role
        self.skills = skills
        self.type = type
        self.questions = questions
        self.shuffleQuestions = shuffleQuestions
        self.enableProctoring = enableProctoring
        self.sections = sections
    }
}

extension Test {
    /// The Library chip should still offer a useful value for the native HackerRank tests list,
    /// even when the API omits explicit library metadata.
    public var libraryFilterValues: [String] {
        cleanFilterValues([library ?? "HackerRank"])
    }

    public var roleFilterValues: [String] {
        let explicit = cleanFilterValues([role])
        guard explicit.isEmpty else { return explicit }

        return cleanFilterValues((tags ?? []).map(Optional.some))
    }

    public var skillFilterValues: [String] {
        let explicit = cleanFilterValues((skills ?? []).map(Optional.some))
        guard explicit.isEmpty else { return explicit }

        return cleanFilterValues((tags ?? []).map(Optional.some))
    }

    public var typeFilterValues: [String] {
        let sectionTypes = (sections ?? []).map { Optional.some($0.displayName) }
        return cleanFilterValues([type] + sectionTypes)
    }

    public var metadataSearchText: String {
        [libraryFilterValues, roleFilterValues, skillFilterValues, typeFilterValues]
            .flatMap { $0 }
            .joined(separator: " ")
    }

    private func cleanFilterValues(_ values: [String?]) -> [String] {
        values.compactMap { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }

            return value == value.lowercased() ? value.capitalized : value
        }
    }
}

/// A named group of questions within a test (the test's `sections`).
///
/// Both `uuid` and `name` are optional: live responses include sections that omit one or
/// both (e.g. an unnamed, ad-hoc section), and a single such section must not fail the whole
/// `Test` (and with it the entire Tests page). `id` falls back through the available fields.
public nonisolated struct TestSection: Codable, Hashable, Identifiable, Sendable {
    /// Stable identifier of the section, when the API provides one.
    public let uuid: String?
    /// The section's display name, when set.
    public let name: String?
    /// Number of questions in the section.
    public let questionCount: Int?
    /// The section's time limit in minutes, if it has its own.
    public let duration: Int?

    public var id: String {
        uuid ?? name ?? "section"
    }

    /// The name to show, falling back to a generic label when the section is unnamed.
    public var displayName: String {
        name ?? "Section"
    }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case questionCount = "questions"
        case duration
    }

    public init(uuid: String? = nil, name: String? = nil, questionCount: Int? = nil, duration: Int? = nil) {
        self.uuid = uuid
        self.name = name
        self.questionCount = questionCount
        self.duration = duration
    }
}

/// A user who can invite candidates to a HackerRank for Work test.
///
/// The `/tests/{id}/inviters` endpoint returns lightweight user records. The shape overlaps
/// `User`, but keeping a small endpoint-specific model avoids implying that every full user
/// administration field is present.
public nonisolated struct TestInviter: Codable, Hashable, Identifiable, Sendable {
    /// The inviter's unique user identifier.
    public let id: String
    /// The inviter's email address, when the API provides one.
    public let email: String
    /// The inviter's first name, when present.
    public let firstName: String?
    /// The inviter's last name, when present.
    public let lastName: String?
    /// The inviter's role or permission label, when present.
    public let role: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "firstname"
        case lastName = "lastname"
        case role
    }

    public init(
        id: String,
        email: String = "",
        firstName: String? = nil,
        lastName: String? = nil,
        role: String? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
    }

    /// Decodes resiliently. Only `id` is required; missing/null emails should not drop
    /// the inviter from the page.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = (container.loggedDecodeIfPresent(String.self, forKey: .email)) ?? ""
        firstName = container.loggedDecodeIfPresent(String.self, forKey: .firstName)
        lastName = container.loggedDecodeIfPresent(String.self, forKey: .lastName)
        role = container.loggedDecodeIfPresent(String.self, forKey: .role)
    }
}
