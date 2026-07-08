//
//  Team.swift
//  HackerRankKit
//

import Foundation

/// A HackerRank for Work team.
///
/// A minimal projection: only the fields a read-only UI typically needs are modelled.
/// `Decodable` ignores any other keys in the response.
public nonisolated struct Team: Codable, Hashable, Identifiable, Sendable {
    /// The unique identifier of the team.
    public let id: String
    /// The team's display name.
    public let name: String
    /// Identifier of the user who owns the team.
    public let owner: String?
    /// ISO-8601 creation timestamp.
    public let createdAt: String?
    /// Number of recruiters on the team.
    public let recruiterCount: Int?
    /// Number of developers on the team.
    public let developerCount: Int?
    /// Number of interviewers on the team.
    public let interviewerCount: Int?
    /// Office locations associated with the team.
    public let locations: [String]?
    /// Departments associated with the team.
    public let departments: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case owner
        case createdAt = "created_at"
        case recruiterCount = "recruiter_count"
        case developerCount = "developer_count"
        case interviewerCount = "interviewer_count"
        case locations
        case departments
    }

    public init(
        id: String,
        name: String,
        owner: String? = nil,
        createdAt: String? = nil,
        recruiterCount: Int? = nil,
        developerCount: Int? = nil,
        interviewerCount: Int? = nil,
        locations: [String]? = nil,
        departments: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.owner = owner
        self.createdAt = createdAt
        self.recruiterCount = recruiterCount
        self.developerCount = developerCount
        self.interviewerCount = interviewerCount
        self.locations = locations
        self.departments = departments
    }
}
