//
//  Test.swift
//  HackerRankKit
//

import Foundation

/// A HackerRank for Work test (assessment).
///
/// Fields mirror the HackerRank for Work API's test resource (`TestsIndex`/`TestsShow`).
/// `Decodable` ignores any other keys in the response, so this decodes live responses
/// without failing on unmodelled fields.
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
    ///
    /// Live responses use `start_time`. The published schema spells it `starttime`; both
    /// are accepted so a row from either shape still decodes.
    public let startTime: String?
    /// ISO-8601 end time of the test window.
    ///
    /// Live responses use `end_time`. The published schema spells it `endtime`; both are
    /// accepted so a row from either shape still decodes.
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
    /// Identifier of the user who locked the test, when it is locked.
    public let lockedBy: String?
    /// Whether the test is still a draft.
    public let draft: Bool?
    /// Programming languages allowed in the test.
    public let languages: [String]?
    /// The details a candidate is asked for before logging into the test.
    public let candidateDetails: [String]?
    /// Text the candidate must acknowledge before logging into the test.
    public let customAcknowledgeText: String?
    /// The score at or above which a candidate passes.
    public let cutoffScore: Int?
    /// Whether the compile button is hidden for coding questions.
    public let hideCompileTest: Bool?
    /// Tags applied to the test.
    public let tags: [String]?
    /// Identifiers of the hiring roles this test targets.
    public let roleIDs: [String]?
    /// Experience levels associated with the test.
    public let experience: [String]?
    /// The source library or collection this test belongs to, when reported by the API.
    public let library: String?
    /// Skills assessed by the test, when reported by the API.
    public let skills: [String]?
    /// The test category or assessment type, when reported by the API.
    public let type: String?
    /// Identifiers of the questions in the test.
    public let questions: [String]?
    /// The test's question sections, when it is organised into them.
    public let sections: [TestSection]?
    /// Whether question order is shuffled per candidate.
    public let shuffleQuestions: Bool?
    /// Identifiers of the users who administer the test and receive its summary reports.
    public let testAdmins: [String]?
    /// Whether head and tail code templates are hidden from candidates.
    public let hideTemplate: Bool?
    /// Whether the candidate is asked to agree to the acknowledgement text.
    public let enableAcknowledgement: Bool?
    /// Whether proctoring is enabled for the test.
    public let enableProctoring: Bool?
    /// Whether candidate webcam snapshots are analysed for suspicious activity.
    public let enableAdvancedProctoring: Bool?
    /// Whether the test runs in HackerRank's secure assessment mode.
    public let enableSecureAssessmentMode: Bool?
    /// Whether machine-learning plagiarism analysis is enabled for the test.
    public let enableMLPlagiarismAnalysis: Bool?
    /// Whether candidates must take an identifying photo before starting.
    public let enablePhotoIdentification: Bool?
    /// The IDE configuration offered to candidates for front-end/back-end/full-stack questions.
    public let ideConfig: String?

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
        case lockedBy = "locked_by"
        case draft
        case languages
        case candidateDetails = "candidate_details"
        case customAcknowledgeText = "custom_acknowledge_text"
        case cutoffScore = "cutoff_score"
        case hideCompileTest = "hide_compile_test"
        case tags
        case roleIDs = "role_ids"
        case experience
        case library
        case skills
        case type
        case questions
        case sections
        case shuffleQuestions = "shuffle_questions"
        case testAdmins = "test_admins"
        case hideTemplate = "hide_template"
        case enableAcknowledgement = "enable_acknowledgement"
        case enableProctoring = "enable_proctoring"
        case enableAdvancedProctoring = "enable_advanced_proctoring"
        case enableSecureAssessmentMode = "enable_secure_assessment_mode"
        case enableMLPlagiarismAnalysis = "enable_ml_plagiarism_analysis"
        case enablePhotoIdentification = "enable_photo_identification"
        case ideConfig = "ide_config"
    }

    /// Schema-only aliases for the assessment window. Live traffic uses ``CodingKeys/startTime`` /
    /// ``CodingKeys/endTime`` (`start_time` / `end_time`); the published document spells them
    /// without the underscore.
    private enum SchemaWindowKeys: String, CodingKey {
        case starttime
        case endtime
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
        lockedBy: String? = nil,
        draft: Bool? = nil,
        languages: [String]? = nil,
        candidateDetails: [String]? = nil,
        customAcknowledgeText: String? = nil,
        cutoffScore: Int? = nil,
        hideCompileTest: Bool? = nil,
        tags: [String]? = nil,
        roleIDs: [String]? = nil,
        experience: [String]? = nil,
        library: String? = nil,
        skills: [String]? = nil,
        type: String? = nil,
        questions: [String]? = nil,
        sections: [TestSection]? = nil,
        shuffleQuestions: Bool? = nil,
        testAdmins: [String]? = nil,
        hideTemplate: Bool? = nil,
        enableAcknowledgement: Bool? = nil,
        enableProctoring: Bool? = nil,
        enableAdvancedProctoring: Bool? = nil,
        enableSecureAssessmentMode: Bool? = nil,
        enableMLPlagiarismAnalysis: Bool? = nil,
        enablePhotoIdentification: Bool? = nil,
        ideConfig: String? = nil
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
        self.lockedBy = lockedBy
        self.draft = draft
        self.languages = languages
        self.candidateDetails = candidateDetails
        self.customAcknowledgeText = customAcknowledgeText
        self.cutoffScore = cutoffScore
        self.hideCompileTest = hideCompileTest
        self.tags = tags
        self.roleIDs = roleIDs
        self.experience = experience
        self.library = library
        self.skills = skills
        self.type = type
        self.questions = questions
        self.sections = sections
        self.shuffleQuestions = shuffleQuestions
        self.testAdmins = testAdmins
        self.hideTemplate = hideTemplate
        self.enableAcknowledgement = enableAcknowledgement
        self.enableProctoring = enableProctoring
        self.enableAdvancedProctoring = enableAdvancedProctoring
        self.enableSecureAssessmentMode = enableSecureAssessmentMode
        self.enableMLPlagiarismAnalysis = enableMLPlagiarismAnalysis
        self.enablePhotoIdentification = enablePhotoIdentification
        self.ideConfig = ideConfig
    }
}

extension Test {
    /// Decodes resiliently. Only `id` and `name` identify an assessment; every other field is
    /// read through ``KeyedDecodingContainer/loggedDecodeIfPresent(_:forKey:)`` so one
    /// unexpected value never drops the whole test from a page.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        uniqueID = container.loggedDecodeIfPresent(String.self, forKey: .uniqueID)
        // Live rows use `start_time`/`end_time`. The published schema (and older fixtures)
        // spell them without the underscore; accept either so a windowed test never looks unset.
        let schemaKeys = try decoder.container(keyedBy: SchemaWindowKeys.self)
        startTime = container.loggedDecodeIfPresent(String.self, forKey: .startTime)
            ?? schemaKeys.loggedDecodeIfPresent(String.self, forKey: .starttime)
        endTime = container.loggedDecodeIfPresent(String.self, forKey: .endTime)
            ?? schemaKeys.loggedDecodeIfPresent(String.self, forKey: .endtime)
        duration = container.loggedDecodeIfPresent(Int.self, forKey: .duration)
        owner = container.loggedDecodeIfPresent(String.self, forKey: .owner)
        instructions = container.loggedDecodeIfPresent(String.self, forKey: .instructions)
        starred = container.loggedDecodeIfPresent(Bool.self, forKey: .starred)
        createdAt = container.loggedDecodeIfPresent(String.self, forKey: .createdAt)
        state = container.loggedDecodeIfPresent(String.self, forKey: .state)
        locked = container.loggedDecodeIfPresent(Bool.self, forKey: .locked)
        lockedBy = container.loggedDecodeIfPresent(String.self, forKey: .lockedBy)
        draft = container.loggedDecodeIfPresent(Bool.self, forKey: .draft)
        languages = container.loggedDecodeIfPresent([String].self, forKey: .languages)
        candidateDetails = container.loggedDecodeIfPresent([String].self, forKey: .candidateDetails)
        customAcknowledgeText = container.loggedDecodeIfPresent(String.self, forKey: .customAcknowledgeText)
        cutoffScore = container.loggedDecodeIfPresent(Int.self, forKey: .cutoffScore)
        hideCompileTest = container.loggedDecodeIfPresent(Bool.self, forKey: .hideCompileTest)
        tags = container.loggedDecodeIfPresent([String].self, forKey: .tags)
        roleIDs = container.loggedDecodeIfPresent([String].self, forKey: .roleIDs)
        experience = container.loggedDecodeIfPresent([String].self, forKey: .experience)
        library = container.loggedDecodeIfPresent(String.self, forKey: .library)
        skills = container.loggedDecodeIfPresent([String].self, forKey: .skills)
        type = container.loggedDecodeIfPresent(String.self, forKey: .type)
        questions = container.loggedDecodeIfPresent([String].self, forKey: .questions)
        sections = TestSection.decodeSlots(from: container, forKey: .sections)
        shuffleQuestions = container.loggedDecodeIfPresent(Bool.self, forKey: .shuffleQuestions)
        testAdmins = container.loggedDecodeIfPresent([String].self, forKey: .testAdmins)
        hideTemplate = container.loggedDecodeIfPresent(Bool.self, forKey: .hideTemplate)
        enableAcknowledgement = container.loggedDecodeIfPresent(Bool.self, forKey: .enableAcknowledgement)
        enableProctoring = container.loggedDecodeIfPresent(Bool.self, forKey: .enableProctoring)
        enableAdvancedProctoring = container.loggedDecodeIfPresent(Bool.self, forKey: .enableAdvancedProctoring)
        enableSecureAssessmentMode = container.loggedDecodeIfPresent(Bool.self, forKey: .enableSecureAssessmentMode)
        enableMLPlagiarismAnalysis = container.loggedDecodeIfPresent(Bool.self, forKey: .enableMLPlagiarismAnalysis)
        enablePhotoIdentification = container.loggedDecodeIfPresent(Bool.self, forKey: .enablePhotoIdentification)
        ideConfig = container.loggedDecodeIfPresent(String.self, forKey: .ideConfig)
    }
}

extension Test {
    /// The Library chip should still offer a useful value for the native HackerRank tests list,
    /// even when the API omits explicit library metadata.
    public var libraryFilterValues: [String] {
        cleanFilterValues([library ?? "HackerRank"])
    }

    public var roleFilterValues: [String] {
        let explicit = cleanFilterValues((roleIDs ?? []).map(Optional.some))
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
/// `Test` (and with it the entire Tests page). `id` falls back through the available fields,
/// ending at ``slot`` so two unnamed sections never share an identity.
public nonisolated struct TestSection: Codable, Hashable, Identifiable, Sendable {
    /// Stable identifier of the section, when the API provides one.
    public let uuid: String?
    /// The section's display name, when set.
    public let name: String?
    /// Number of questions in the section.
    public let questionCount: Int?
    /// The section's time limit in minutes, if it has its own.
    public let duration: Int?
    /// The section's slot within the test's `sections` field: the documented object's key, or
    /// the section's position when a deployment returns the field as an array. Assigned by
    /// ``Test``'s decoder rather than read from a wire key of its own.
    public let slot: String?

    /// A stable identity. The server's `uuid` when it has one, otherwise the section's slot
    /// (qualified by its name when it has one) so unnamed sections stay distinct.
    public var id: String {
        if let uuid, !uuid.isEmpty { return uuid }
        if let slot, !slot.isEmpty {
            guard let name, !name.isEmpty else { return slot }

            return "\(slot)-\(name)"
        }
        return name ?? "section"
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
        case slot
    }

    public init(
        uuid: String? = nil,
        name: String? = nil,
        questionCount: Int? = nil,
        duration: Int? = nil,
        slot: String? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.questionCount = questionCount
        self.duration = duration
        self.slot = slot
    }
}

extension TestSection {
    /// Decodes the test's `sections` field. Live accounts return an **array** of section
    /// objects; the published schema documents an object of slot data. Both shapes are
    /// accepted — decoding only one made the other throw, and the lenient page decoder then
    /// dropped the entire assessment row.
    ///
    /// Each decoded section carries the slot it came from (the object key, or the array index)
    /// so ``TestSection/id`` stays unique across unnamed sections.
    nonisolated static func decodeSlots(
        from container: KeyedDecodingContainer<Test.CodingKeys>,
        forKey key: Test.CodingKeys
    ) -> [TestSection]? {
        if let array = container.loggedDecodeIfPresent([LenientElement<TestSection>].self, forKey: key) {
            return array.enumerated().compactMap { index, element in
                element.value?.inSlot(String(index))
            }
        }
        guard let object = container.loggedDecodeIfPresent([String: LenientElement<TestSection>].self, forKey: key)
        else { return nil }

        let sections = object.sorted { $0.key < $1.key }.compactMap { slot, element in
            element.value?.inSlot(slot)
        }
        // An object whose values are not section records decodes to nothing; report that as
        // "no sections modelled" rather than as an empty section list.
        return sections.isEmpty && !object.isEmpty ? nil : sections
    }

    /// A copy stamped with the slot it occupies, unless the value already carried one.
    private nonisolated func inSlot(_ slot: String) -> Self {
        Self(uuid: uuid, name: name, questionCount: questionCount, duration: duration, slot: self.slot ?? slot)
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
