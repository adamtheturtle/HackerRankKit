//
//  Team.swift
//  HackerRankKit
//

import Foundation

/// A HackerRank for Work team.
///
/// Fields mirror the `TeamIndex`/`TeamShow` schemas. `Decodable` ignores any other keys in
/// the response.
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
    /// The maximum number of recruiters the team may have.
    public let recruiterCap: Int?
    /// The maximum number of developers the team may have.
    public let developerCap: Int?
    /// The display name used on candidate invite emails sent by this team.
    public let inviteAs: String?
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
        case recruiterCap = "recruiter_cap"
        case developerCap = "developer_cap"
        case inviteAs = "invite_as"
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
        recruiterCap: Int? = nil,
        developerCap: Int? = nil,
        inviteAs: String? = nil,
        locations: [String]? = nil,
        departments: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.owner = owner
        self.createdAt = createdAt
        self.recruiterCount = recruiterCount
        self.developerCount = developerCount
        self.recruiterCap = recruiterCap
        self.developerCap = developerCap
        self.inviteAs = inviteAs
        self.locations = locations
        self.departments = departments
    }
}
