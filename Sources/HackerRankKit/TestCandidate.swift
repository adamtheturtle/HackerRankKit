//
//  TestCandidate.swift
//  HackerRankKit
//

import Foundation

/// HackerRank recruitment-pipeline values carried by the candidate `ats_state` field.
///
/// These are the stable values documented by HackerRank. Keep the wire model's raw
/// integer for source compatibility; callers can validate or interpret it with
/// `CandidateATSState(rawValue:)`.
public nonisolated enum CandidateATSState: Int, CaseIterable, Codable, Hashable, Sendable {
    case notSet = 0
    case evaluationRequired = 1
    case qualified = 2
    case failed = 3
    case phoneInterviewOne = 4
    case phoneInterviewTwo = 5
    case phoneInterviewThree = 6
    case offerSent = 7
    case offerNegotiation = 8
    case offerAccepted = 9
    case offerDeclined = 10
    case onHold = 11
    case phoneInterviewCleared = 12
    case phoneInterviewFailed = 13
    case technicalInterviewCleared = 14
    case technicalInterviewFailed = 15
    case humanResourcesInterviewCleared = 16
    case humanResourcesInterviewFailed = 17
    case phoneInterview = 18
    case technicalInterview = 19
    case humanResourcesInterview = 20
    case hired = 21
    case rejected = 22
}

/// One piece of candidate information collected before the assessment (the candidate
/// resource's `candidate_details` entries).
public nonisolated struct CandidateDetail: Codable, Hashable, Identifiable, Sendable {
    /// The field's wire name.
    public let fieldName: String?
    /// The field's human-readable title.
    public let title: String?
    /// The value the candidate supplied.
    public let value: String?

    public var id: String {
        fieldName ?? title ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case fieldName = "field_name"
        case title
        case value
    }

    public init(fieldName: String? = nil, title: String? = nil, value: String? = nil) {
        self.fieldName = fieldName
        self.title = title
        self.value = value
    }
}

/// One question's contribution to a candidate's attempt (the candidate resource's
/// `questions` field, documented as `QuestionScore`).
///
/// The API keys these by question id, so ``questionID`` carries the key the record was
/// found under rather than a wire field of its own.
public nonisolated struct QuestionScore: Codable, Hashable, Identifiable, Sendable {
    /// Identifier of the question this score belongs to.
    public let questionID: String?
    /// The candidate's score for the question.
    public let score: Double?
    /// Whether the candidate answered the question.
    public let answered: Bool?
    /// The candidate's answer, when the API returns one.
    public let answer: String?
    /// The question's name.
    public let name: String?
    /// A preview of the question.
    public let preview: String?

    public var id: String {
        questionID ?? name ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case questionID = "question_id"
        case score
        case answered
        case answer
        case name
        case preview
    }

    public init(
        questionID: String? = nil,
        score: Double? = nil,
        answered: Bool? = nil,
        answer: String? = nil,
        name: String? = nil,
        preview: String? = nil
    ) {
        self.questionID = questionID
        self.score = score
        self.answered = answered
        self.answer = answer
        self.name = name
        self.preview = preview
    }

    /// A copy carrying the question id it was keyed under, unless it already had one.
    nonisolated func identified(by questionID: String) -> Self {
        Self(
            questionID: self.questionID ?? questionID,
            score: score,
            answered: answered,
            answer: answer,
            name: name,
            preview: preview
        )
    }
}

/// A candidate associated with a HackerRank for Work test.
///
/// Fields mirror the `TestCandidateIndex`/`TestCandidateShow` schemas. Several of them —
/// the report links, the per-question answers, the IP address, and the proctoring images —
/// are sensitive and are best gated behind an explicit reveal in a UI. `Decodable` ignores
/// any other keys, so this decodes live responses without failing on unmodelled fields.
public nonisolated struct TestCandidate: Codable, Hashable, Identifiable, Sendable {
    /// The unique identifier of the candidate record.
    public let id: String
    /// The candidate's email address.
    public let email: String
    /// The candidate's full name, if known.
    public let fullName: String?
    /// The candidate's raw score.
    public let score: Double?
    /// The candidate's score as a percentage.
    public let percentageScore: Double?
    /// Identifier of the test the candidate took.
    public let test: String?
    /// Identifier of the user who invited the candidate.
    public let user: String?
    /// Numeric status code of the candidate's attempt.
    public let status: Int?
    /// Applicant-tracking-system state code.
    public let atsState: Int?
    /// Integrity (proctoring) status string.
    public let integrityStatus: String?
    /// The server's detailed explanation of the integrity signals behind ``integrityStatus``.
    public let integritySummary: String?
    /// ISO-8601 time the candidate started the attempt.
    public let attemptStartTime: String?
    /// ISO-8601 time the candidate finished the attempt.
    public let attemptEndTime: String?
    /// The events recorded during the attempt (logins, tab switches, pastes, submissions).
    ///
    /// The schema types these as strings while describing each entry as an object of
    /// `id`/`attempt_id`/`event`/`data`/`inserttime`, so they are kept as raw JSON values
    /// and both shapes survive.
    public let attemptEvents: [HackerRankJSONValue]?
    /// Whether the invitation email has been sent.
    public let inviteEmailDone: Bool?
    /// Whether the invitation is still valid.
    public let inviteValid: Bool?
    /// ISO-8601 time the candidate was invited.
    public let invitedOn: String?
    /// ISO-8601 time from which the invitation is usable.
    public let inviteValidFrom: String?
    /// ISO-8601 time after which the invitation expires.
    public let inviteValidTo: String?
    /// The candidate's invitation link.
    public let inviteLink: String?
    /// Free-form metadata attached to the invitation.
    public let inviteMetadata: [String: HackerRankJSONValue]?
    /// The evaluator assigned to the candidate, when one differs from the test's admins.
    public let evaluatorEmail: String?
    /// Where the candidate is redirected after finishing the test.
    public let testFinishURL: String?
    /// The webhook the candidate's report is posted to.
    public let testResultURL: String?
    /// Whether score and status updates are sent to ``testResultURL``.
    public let acceptResultUpdates: Bool?
    /// Tags applied to the candidate.
    public let tags: [String]?
    /// Reviewer feedback, if any.
    public let feedback: String?
    /// URL of the candidate's report, for users with access to the test.
    public let reportURL: String?
    /// URL of the candidate's report for every user in the account.
    public let authenticatedReportURL: String?
    /// URL of the candidate's report as a downloadable PDF.
    public let pdfURL: String?
    /// The candidate's score split per tag.
    public let scoresTagsSplit: [String: HackerRankJSONValue]?
    /// The candidate's score split per skill.
    public let scoresSkillsSplit: [String: HackerRankJSONValue]?
    /// Additional time granted to the candidate, in minutes.
    public let addedTime: String?
    /// Additional time granted but not yet claimed, in minutes.
    public let unclaimedAddedTime: Int?
    /// The comments left on the report's summary tab.
    public let comments: [String: HackerRankJSONValue]?
    /// HackerRank's summary of the candidate's performance.
    public let performanceSummary: String?
    /// The IP address the attempt came from. Personal data — show it only where the
    /// viewer is authorised to audit attempts.
    public let ipAddress: String?
    /// The candidate's per-question scores, keyed into ``QuestionScore/questionID``.
    public let questionScores: [QuestionScore]?
    /// Per-question plagiarism detail. Deprecated by the API in favour of
    /// ``integrityStatus`` and ``integritySummary``.
    public let plagiarism: [String: HackerRankJSONValue]?
    /// Whether plagiarism was flagged. Deprecated by the API in favour of
    /// ``integrityStatus`` and ``integritySummary``.
    public let plagiarismStatus: Bool?
    /// The strongest per-question code-similarity match. Deprecated by the API in favour
    /// of ``integrityStatus`` and ``integritySummary``.
    public let maxCodeSimilarity: [String: HackerRankJSONValue]?
    /// The candidate information collected before the assessment.
    public let candidateDetails: [CandidateDetail]?
    /// Number of times the candidate left the test window (e.g. switched tabs/apps) — a
    /// proctoring signal.
    public let outOfWindowEvents: Int?
    /// Total time, in seconds, the candidate spent outside the test window.
    public let outOfWindowDuration: Double?
    /// Number of paste actions detected in the code editor — a proctoring signal.
    public let editorPasteCount: Int?
    /// URLs of the webcam images captured while proctoring. Personal data — show these
    /// only where the viewer is authorised to review an attempt.
    public let proctorImages: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case score
        case percentageScore = "percentage_score"
        case test
        case user
        case status
        case atsState = "ats_state"
        case integrityStatus = "integrity_status"
        case integritySummary = "integrity_summary"
        case attemptStartTime = "attempt_starttime"
        case attemptEndTime = "attempt_endtime"
        case attemptEvents = "attempt_events"
        case inviteEmailDone = "invite_email_done"
        case inviteValid = "invite_valid"
        case invitedOn = "invited_on"
        case inviteValidFrom = "invite_valid_from"
        case inviteValidTo = "invite_valid_to"
        case inviteLink = "invite_link"
        case inviteMetadata = "invite_metadata"
        case evaluatorEmail = "evaluator_email"
        case testFinishURL = "test_finish_url"
        case testResultURL = "test_result_url"
        case acceptResultUpdates = "accept_result_updates"
        case tags
        case feedback
        case reportURL = "report_url"
        case authenticatedReportURL = "authenticated_report_url"
        case pdfURL = "pdf_url"
        case scoresTagsSplit = "scores_tags_split"
        case scoresSkillsSplit = "scores_skills_split"
        case addedTime = "added_time"
        case unclaimedAddedTime = "unclaimed_added_time"
        case comments
        case performanceSummary = "performance_summary"
        case ipAddress = "ip_address"
        case questionScores = "questions"
        case plagiarism
        case plagiarismStatus = "plagiarism_status"
        case maxCodeSimilarity = "max_code_similarity"
        case candidateDetails = "candidate_details"
        case outOfWindowEvents = "out_of_window_events"
        case outOfWindowDuration = "out_of_window_duration"
        case editorPasteCount = "editor_paste_count"
        case proctorImages = "proctor_images"
    }

    public init(
        id: String,
        email: String,
        fullName: String? = nil,
        score: Double? = nil,
        percentageScore: Double? = nil,
        test: String? = nil,
        user: String? = nil,
        status: Int? = nil,
        atsState: Int? = nil,
        integrityStatus: String? = nil,
        integritySummary: String? = nil,
        attemptStartTime: String? = nil,
        attemptEndTime: String? = nil,
        attemptEvents: [HackerRankJSONValue]? = nil,
        inviteEmailDone: Bool? = nil,
        inviteValid: Bool? = nil,
        invitedOn: String? = nil,
        inviteValidFrom: String? = nil,
        inviteValidTo: String? = nil,
        inviteLink: String? = nil,
        inviteMetadata: [String: HackerRankJSONValue]? = nil,
        evaluatorEmail: String? = nil,
        testFinishURL: String? = nil,
        testResultURL: String? = nil,
        acceptResultUpdates: Bool? = nil,
        tags: [String]? = nil,
        feedback: String? = nil,
        reportURL: String? = nil,
        authenticatedReportURL: String? = nil,
        pdfURL: String? = nil,
        scoresTagsSplit: [String: HackerRankJSONValue]? = nil,
        scoresSkillsSplit: [String: HackerRankJSONValue]? = nil,
        addedTime: String? = nil,
        unclaimedAddedTime: Int? = nil,
        comments: [String: HackerRankJSONValue]? = nil,
        performanceSummary: String? = nil,
        ipAddress: String? = nil,
        questionScores: [QuestionScore]? = nil,
        plagiarism: [String: HackerRankJSONValue]? = nil,
        plagiarismStatus: Bool? = nil,
        maxCodeSimilarity: [String: HackerRankJSONValue]? = nil,
        candidateDetails: [CandidateDetail]? = nil,
        outOfWindowEvents: Int? = nil,
        outOfWindowDuration: Double? = nil,
        editorPasteCount: Int? = nil,
        proctorImages: [String]? = nil
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.score = score
        self.percentageScore = percentageScore
        self.test = test
        self.user = user
        self.status = status
        self.atsState = atsState
        self.integrityStatus = integrityStatus
        self.integritySummary = integritySummary
        self.attemptStartTime = attemptStartTime
        self.attemptEndTime = attemptEndTime
        self.attemptEvents = attemptEvents
        self.inviteEmailDone = inviteEmailDone
        self.inviteValid = inviteValid
        self.invitedOn = invitedOn
        self.inviteValidFrom = inviteValidFrom
        self.inviteValidTo = inviteValidTo
        self.inviteLink = inviteLink
        self.inviteMetadata = inviteMetadata
        self.evaluatorEmail = evaluatorEmail
        self.testFinishURL = testFinishURL
        self.testResultURL = testResultURL
        self.acceptResultUpdates = acceptResultUpdates
        self.tags = tags
        self.feedback = feedback
        self.reportURL = reportURL
        self.authenticatedReportURL = authenticatedReportURL
        self.pdfURL = pdfURL
        self.scoresTagsSplit = scoresTagsSplit
        self.scoresSkillsSplit = scoresSkillsSplit
        self.addedTime = addedTime
        self.unclaimedAddedTime = unclaimedAddedTime
        self.comments = comments
        self.performanceSummary = performanceSummary
        self.ipAddress = ipAddress
        self.questionScores = questionScores
        self.plagiarism = plagiarism
        self.plagiarismStatus = plagiarismStatus
        self.maxCodeSimilarity = maxCodeSimilarity
        self.candidateDetails = candidateDetails
        self.outOfWindowEvents = outOfWindowEvents
        self.outOfWindowDuration = outOfWindowDuration
        self.editorPasteCount = editorPasteCount
        self.proctorImages = proctorImages
    }
}

extension TestCandidate {
    /// The opt-in fields a candidate detail read asks for by default. The API omits each
    /// of these unless it is named in `additional_fields`, so a detail read without them
    /// returns little more than the list row.
    public static let detailAdditionalFields = ["questions", "attempt_events", "comments", "ip_address"]
}

extension TestCandidate {
    /// Decodes resiliently. `email` is required in the schema but can be absent or null on live
    /// records (e.g. an invited candidate who hasn't registered); the page decoder drops any
    /// element that throws, so without this those candidates silently vanish from the list.
    /// It defaults to "" so the record still appears. Only `id` is truly required.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = (container.loggedDecodeIfPresent(String.self, forKey: .email)) ?? ""
        fullName = container.loggedDecodeIfPresent(String.self, forKey: .fullName)
        score = container.loggedDecodeIfPresent(Double.self, forKey: .score)
        percentageScore = container.loggedDecodeIfPresent(Double.self, forKey: .percentageScore)
        test = container.loggedDecodeIfPresent(String.self, forKey: .test)
        user = container.loggedDecodeIfPresent(String.self, forKey: .user)
        status = container.loggedDecodeIfPresent(Int.self, forKey: .status)
        atsState = container.loggedDecodeIfPresent(Int.self, forKey: .atsState)
        integrityStatus = container.loggedDecodeIfPresent(String.self, forKey: .integrityStatus)
        integritySummary = container.loggedDecodeIfPresent(String.self, forKey: .integritySummary)
        attemptStartTime = container.loggedDecodeIfPresent(String.self, forKey: .attemptStartTime)
        attemptEndTime = container.loggedDecodeIfPresent(String.self, forKey: .attemptEndTime)
        attemptEvents = container.loggedDecodeIfPresent([HackerRankJSONValue].self, forKey: .attemptEvents)
        inviteEmailDone = container.loggedDecodeIfPresent(Bool.self, forKey: .inviteEmailDone)
        inviteValid = container.loggedDecodeIfPresent(Bool.self, forKey: .inviteValid)
        invitedOn = container.loggedDecodeIfPresent(String.self, forKey: .invitedOn)
        inviteValidFrom = container.loggedDecodeIfPresent(String.self, forKey: .inviteValidFrom)
        inviteValidTo = container.loggedDecodeIfPresent(String.self, forKey: .inviteValidTo)
        inviteLink = container.loggedDecodeIfPresent(String.self, forKey: .inviteLink)
        inviteMetadata = container.loggedDecodeIfPresent([String: HackerRankJSONValue].self, forKey: .inviteMetadata)
        evaluatorEmail = container.loggedDecodeIfPresent(String.self, forKey: .evaluatorEmail)
        testFinishURL = container.loggedDecodeIfPresent(String.self, forKey: .testFinishURL)
        testResultURL = container.loggedDecodeIfPresent(String.self, forKey: .testResultURL)
        acceptResultUpdates = container.loggedDecodeIfPresent(Bool.self, forKey: .acceptResultUpdates)
        tags = container.loggedDecodeIfPresent([String].self, forKey: .tags)
        feedback = container.loggedDecodeIfPresent(String.self, forKey: .feedback)
        reportURL = container.loggedDecodeIfPresent(String.self, forKey: .reportURL)
        authenticatedReportURL = container.loggedDecodeIfPresent(String.self, forKey: .authenticatedReportURL)
        pdfURL = container.loggedDecodeIfPresent(String.self, forKey: .pdfURL)
        scoresTagsSplit = container.loggedDecodeIfPresent([String: HackerRankJSONValue].self, forKey: .scoresTagsSplit)
        scoresSkillsSplit = container.loggedDecodeIfPresent(
            [String: HackerRankJSONValue].self, forKey: .scoresSkillsSplit
        )
        addedTime = container.loggedDecodeIfPresent(String.self, forKey: .addedTime)
        unclaimedAddedTime = container.loggedDecodeIfPresent(Int.self, forKey: .unclaimedAddedTime)
        comments = container.loggedDecodeIfPresent([String: HackerRankJSONValue].self, forKey: .comments)
        performanceSummary = container.loggedDecodeIfPresent(String.self, forKey: .performanceSummary)
        ipAddress = container.loggedDecodeIfPresent(String.self, forKey: .ipAddress)
        questionScores = Self.decodeQuestionScores(container)
        plagiarism = container.loggedDecodeIfPresent([String: HackerRankJSONValue].self, forKey: .plagiarism)
        plagiarismStatus = container.loggedDecodeIfPresent(Bool.self, forKey: .plagiarismStatus)
        maxCodeSimilarity = container.loggedDecodeIfPresent(
            [String: HackerRankJSONValue].self, forKey: .maxCodeSimilarity
        )
        candidateDetails = container.loggedDecodeIfPresent([CandidateDetail].self, forKey: .candidateDetails)
        outOfWindowEvents = container.loggedDecodeIfPresent(Int.self, forKey: .outOfWindowEvents)
        outOfWindowDuration = container.loggedDecodeIfPresent(Double.self, forKey: .outOfWindowDuration)
        editorPasteCount = container.loggedDecodeIfPresent(Int.self, forKey: .editorPasteCount)
        proctorImages = container.loggedDecodeIfPresent([String].self, forKey: .proctorImages)
    }

    /// Decodes the `questions` field, which the API returns as an object keyed by question
    /// id. An array is accepted too, so a deployment that returns one is not dropped.
    private nonisolated static func decodeQuestionScores(
        _ container: KeyedDecodingContainer<CodingKeys>
    ) -> [QuestionScore]? {
        if let keyed = container.loggedDecodeIfPresent([String: QuestionScore].self, forKey: .questionScores) {
            return keyed.sorted { $0.key < $1.key }.map { id, score in score.identified(by: id) }
        }

        return container.loggedDecodeIfPresent([QuestionScore].self, forKey: .questionScores)
    }
}
