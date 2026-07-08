//
//  Question.swift
//  HackerRankKit
//

import Foundation

/// A HackerRank for Work question.
///
/// Only the fields a read-only UI typically needs are modelled; `Decodable` ignores any
/// other keys, so this decodes live responses without failing on unmodelled fields.
public nonisolated struct Question: Codable, Hashable, Identifiable, Sendable {
    /// The unique identifier of the question.
    public let id: String
    /// A short, human-shareable identifier for the question.
    public let uniqueID: String?
    /// The question type (e.g. "code", "mcq").
    public let type: String
    /// The question's display name.
    public let name: String
    /// Identifier of the user who owns the question.
    public let owner: String?
    /// ISO-8601 creation timestamp.
    public let createdAt: String?
    /// The lifecycle status of the question.
    public let status: String?
    /// Programming languages allowed for the question.
    public let languages: [String]?
    /// The problem statement, typically Markdown or HTML.
    public let problemStatement: String?
    /// Recommended solving time in minutes.
    public let recommendedDuration: Int?
    /// Tags applied to the question.
    public let tags: [String]?
    /// The maximum achievable score.
    public let maxScore: Double?
    /// Skills the question assesses.
    public let skills: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case uniqueID = "unique_id"
        case type
        case name
        case owner
        case createdAt = "created_at"
        case status
        case languages
        case problemStatement = "problem_statement"
        case recommendedDuration = "recommended_duration"
        case tags
        case maxScore = "max_score"
        case skills
    }

    public init(
        id: String,
        uniqueID: String? = nil,
        type: String,
        name: String,
        owner: String? = nil,
        createdAt: String? = nil,
        status: String? = nil,
        languages: [String]? = nil,
        problemStatement: String? = nil,
        recommendedDuration: Int? = nil,
        tags: [String]? = nil,
        maxScore: Double? = nil,
        skills: [String]? = nil
    ) {
        self.id = id
        self.uniqueID = uniqueID
        self.type = type
        self.name = name
        self.owner = owner
        self.createdAt = createdAt
        self.status = status
        self.languages = languages
        self.problemStatement = problemStatement
        self.recommendedDuration = recommendedDuration
        self.tags = tags
        self.maxScore = maxScore
        self.skills = skills
    }
}
