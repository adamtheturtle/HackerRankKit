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

/// A candidate associated with a HackerRank for Work test.
///
/// Only the fields a read-only UI typically needs are modelled; `Decodable` ignores any
/// other keys, so this decodes live responses without failing on unmodelled fields.
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
    /// Numeric status code of the candidate's attempt.
    public let status: Int?
    /// Applicant-tracking-system state code.
    public let atsState: Int?
    /// Integrity (proctoring) status string.
    public let integrityStatus: String?
    /// ISO-8601 time the candidate started the attempt.
    public let attemptStartTime: String?
    /// ISO-8601 time the candidate finished the attempt.
    public let attemptEndTime: String?
    /// Tags applied to the candidate.
    public let tags: [String]?
    /// Reviewer feedback, if any.
    public let feedback: String?
    /// URL of the candidate's report.
    public let reportURL: String?
    /// URL of the candidate's report as a downloadable PDF.
    public let pdfURL: String?
    /// Whether plagiarism was flagged.
    public let plagiarismStatus: Bool?
    /// Number of times the candidate left the test window (e.g. switched tabs/apps) — a
    /// proctoring signal.
    public let outOfWindowEvents: Int?
    /// Total time, in seconds, the candidate spent outside the test window.
    public let outOfWindowDuration: Double?
    /// Number of paste actions detected in the code editor — a proctoring signal.
    public let editorPasteCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case score
        case percentageScore = "percentage_score"
        case test
        case status
        case atsState = "ats_state"
        case integrityStatus = "integrity_status"
        case attemptStartTime = "attempt_starttime"
        case attemptEndTime = "attempt_endtime"
        case tags
        case feedback
        case reportURL = "report_url"
        case pdfURL = "pdf_url"
        case plagiarismStatus = "plagiarism_status"
        case outOfWindowEvents = "out_of_window_events"
        case outOfWindowDuration = "out_of_window_duration"
        case editorPasteCount = "editor_paste_count"
    }

    public init(
        id: String,
        email: String,
        fullName: String? = nil,
        score: Double? = nil,
        percentageScore: Double? = nil,
        test: String? = nil,
        status: Int? = nil,
        atsState: Int? = nil,
        integrityStatus: String? = nil,
        attemptStartTime: String? = nil,
        attemptEndTime: String? = nil,
        tags: [String]? = nil,
        feedback: String? = nil,
        reportURL: String? = nil,
        pdfURL: String? = nil,
        plagiarismStatus: Bool? = nil,
        outOfWindowEvents: Int? = nil,
        outOfWindowDuration: Double? = nil,
        editorPasteCount: Int? = nil
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.score = score
        self.percentageScore = percentageScore
        self.test = test
        self.status = status
        self.atsState = atsState
        self.integrityStatus = integrityStatus
        self.attemptStartTime = attemptStartTime
        self.attemptEndTime = attemptEndTime
        self.tags = tags
        self.feedback = feedback
        self.reportURL = reportURL
        self.pdfURL = pdfURL
        self.plagiarismStatus = plagiarismStatus
        self.outOfWindowEvents = outOfWindowEvents
        self.outOfWindowDuration = outOfWindowDuration
        self.editorPasteCount = editorPasteCount
    }
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
        status = container.loggedDecodeIfPresent(Int.self, forKey: .status)
        atsState = container.loggedDecodeIfPresent(Int.self, forKey: .atsState)
        integrityStatus = container.loggedDecodeIfPresent(String.self, forKey: .integrityStatus)
        attemptStartTime = container.loggedDecodeIfPresent(String.self, forKey: .attemptStartTime)
        attemptEndTime = container.loggedDecodeIfPresent(String.self, forKey: .attemptEndTime)
        tags = container.loggedDecodeIfPresent([String].self, forKey: .tags)
        feedback = container.loggedDecodeIfPresent(String.self, forKey: .feedback)
        reportURL = container.loggedDecodeIfPresent(String.self, forKey: .reportURL)
        pdfURL = container.loggedDecodeIfPresent(String.self, forKey: .pdfURL)
        plagiarismStatus = container.loggedDecodeIfPresent(Bool.self, forKey: .plagiarismStatus)
        outOfWindowEvents = container.loggedDecodeIfPresent(Int.self, forKey: .outOfWindowEvents)
        outOfWindowDuration = container.loggedDecodeIfPresent(Double.self, forKey: .outOfWindowDuration)
        editorPasteCount = container.loggedDecodeIfPresent(Int.self, forKey: .editorPasteCount)
    }
}
