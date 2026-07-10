//
//  TestInviter.swift
//  HackerRankKit
//

import Foundation

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
