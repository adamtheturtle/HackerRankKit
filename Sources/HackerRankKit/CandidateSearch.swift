//
//  CandidateSearch.swift
//  HackerRankKit
//

import Foundation

/// One candidate matched by the organisation-wide candidate search
/// (`GET /candidates/search` → `CandidateSearchResult`).
///
/// This is **not** a `TestCandidate`: the search returns a person plus every test attempt
/// of theirs the caller can see, keyed by `uuid` rather than by a per-test candidate id.
public nonisolated struct CandidateSearchResult: Decodable, Hashable, Identifiable, Sendable {
    /// The candidate's unique identifier (the response's `uuid`). Optional so a row the
    /// server returns without one still reaches the caller instead of colliding with
    /// every other id-less row.
    public let id: String?
    /// The candidate's name.
    public let name: String?
    /// The candidate's email address.
    public let email: String?
    /// ISO-8601 time the candidate record was created.
    public let createdAt: String?
    /// ISO-8601 time the candidate record was last updated.
    public let updatedAt: String?
    /// Every accessible test attempt for this candidate.
    public let attempts: [CandidateSearchAttempt]

    enum CodingKeys: String, CodingKey {
        case id = "uuid"
        case name
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case attempts
    }

    public init(
        id: String? = nil,
        name: String? = nil,
        email: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        attempts: [CandidateSearchAttempt] = []
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attempts = attempts
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.loggedDecodeIfPresent(String.self, forKey: .id)
        name = container.loggedDecodeIfPresent(String.self, forKey: .name)
        email = container.loggedDecodeIfPresent(String.self, forKey: .email)
        createdAt = container.loggedDecodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = container.loggedDecodeIfPresent(String.self, forKey: .updatedAt)
        attempts = (container.loggedDecodeIfPresent([CandidateSearchAttempt].self, forKey: .attempts)) ?? []
    }
}

/// One test attempt attached to a candidate search result
/// (`CandidateSearchAttemptResult`).
public nonisolated struct CandidateSearchAttempt: Decodable, Hashable, Identifiable, Sendable {
    /// Identifier of the attempt.
    public let id: String?
    /// Identifier of the test that was attempted.
    public let testID: String?
    /// The candidate's score for this attempt.
    public let score: Double?
    /// The candidate's percentage score for this attempt.
    public let percentageScore: Double?
    /// URL of the report for this attempt.
    public let reportURL: String?
    /// ISO-8601 time the attempt started.
    public let attemptStartTime: String?
    /// ISO-8601 time the attempt ended.
    public let attemptEndTime: String?

    enum CodingKeys: String, CodingKey {
        case id = "attempt_id"
        case testID = "test_id"
        case score
        case percentageScore = "percentage_score"
        case reportURL = "report_url"
        case attemptStartTime = "attempt_starttime"
        case attemptEndTime = "attempt_endtime"
    }

    public init(
        id: String? = nil,
        testID: String? = nil,
        score: Double? = nil,
        percentageScore: Double? = nil,
        reportURL: String? = nil,
        attemptStartTime: String? = nil,
        attemptEndTime: String? = nil
    ) {
        self.id = id
        self.testID = testID
        self.score = score
        self.percentageScore = percentageScore
        self.reportURL = reportURL
        self.attemptStartTime = attemptStartTime
        self.attemptEndTime = attemptEndTime
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.loggedDecodeIfPresent(String.self, forKey: .id)
        testID = container.loggedDecodeIfPresent(String.self, forKey: .testID)
        score = container.loggedDecodeIfPresent(Double.self, forKey: .score)
        percentageScore = container.loggedDecodeIfPresent(Double.self, forKey: .percentageScore)
        reportURL = container.loggedDecodeIfPresent(String.self, forKey: .reportURL)
        attemptStartTime = container.loggedDecodeIfPresent(String.self, forKey: .attemptStartTime)
        attemptEndTime = container.loggedDecodeIfPresent(String.self, forKey: .attemptEndTime)
    }
}
