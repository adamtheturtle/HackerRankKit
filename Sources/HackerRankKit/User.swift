//
//  User.swift
//  HackerRankKit
//

import Foundation

/// A HackerRank for Work user (a member of the organisation).
///
/// A minimal projection: only the fields a read-only UI typically needs are modelled.
/// `Decodable` ignores any other keys in the response.
public nonisolated struct User: Codable, Hashable, Identifiable, Sendable {
    /// The unique identifier of the user.
    public let id: String
    /// The user's email address.
    public let email: String
    /// The user's first name.
    public let firstName: String?
    /// The user's last name.
    public let lastName: String?
    /// The user's country.
    public let country: String?
    /// The user's role in the organisation.
    public let role: String?
    /// The user's account status.
    public let status: String?
    /// Identifiers of the teams the user belongs to.
    public let teams: [String]?
    /// Whether the user account is activated.
    public let activated: Bool?
    /// Whether the user is a company administrator.
    public let companyAdmin: Bool?
    /// Whether the user is a team administrator.
    public let teamAdmin: Bool?
    /// ISO-8601 timestamp of the user's last activity, if known.
    public let lastActivityTime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "firstname"
        case lastName = "lastname"
        case country
        case role
        case status
        case teams
        case activated
        case companyAdmin = "company_admin"
        case teamAdmin = "team_admin"
        case lastActivityTime = "last_activity_time"
    }

    public init(
        id: String,
        email: String,
        firstName: String? = nil,
        lastName: String? = nil,
        country: String? = nil,
        role: String? = nil,
        status: String? = nil,
        teams: [String]? = nil,
        activated: Bool? = nil,
        companyAdmin: Bool? = nil,
        teamAdmin: Bool? = nil,
        lastActivityTime: String? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.country = country
        self.role = role
        self.status = status
        self.teams = teams
        self.activated = activated
        self.companyAdmin = companyAdmin
        self.teamAdmin = teamAdmin
        self.lastActivityTime = lastActivityTime
    }
}

extension User {
    /// Decodes resiliently. `email` is required in the schema but can be absent or null on live
    /// records (SSO members, pending invites, service accounts); the page decoder drops any
    /// element that throws, so without this those users silently vanish from a People list.
    /// It defaults to "" so the record still appears. Only `id` is truly required.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = (container.loggedDecodeIfPresent(String.self, forKey: .email)) ?? ""
        firstName = container.loggedDecodeIfPresent(String.self, forKey: .firstName)
        lastName = container.loggedDecodeIfPresent(String.self, forKey: .lastName)
        country = container.loggedDecodeIfPresent(String.self, forKey: .country)
        role = container.loggedDecodeIfPresent(String.self, forKey: .role)
        status = container.loggedDecodeIfPresent(String.self, forKey: .status)
        teams = container.loggedDecodeIfPresent([String].self, forKey: .teams)
        activated = container.loggedDecodeIfPresent(Bool.self, forKey: .activated)
        companyAdmin = container.loggedDecodeIfPresent(Bool.self, forKey: .companyAdmin)
        teamAdmin = container.loggedDecodeIfPresent(Bool.self, forKey: .teamAdmin)
        lastActivityTime = container.loggedDecodeIfPresent(String.self, forKey: .lastActivityTime)
    }
}
