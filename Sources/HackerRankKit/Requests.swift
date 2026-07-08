//
//  Requests.swift
//  HackerRankKit
//

import Foundation

// The request bodies and response echoes for `HackerRankClient`'s write flows.
// The request types are module-internal (only the client builds them); the response
// echoes are public (they are the return types of the client's write methods) and
// all-optional so a 2xx never fails to decode on an unexpected shape.

/// The body sent when inviting a candidate to a test. Encoded as the API's
/// snake-case JSON; a blank name is omitted entirely rather than sent empty.
nonisolated struct InviteCandidateRequest: Encodable {
    let email: String
    let fullName: String?
    let sendEmail: Bool

    enum CodingKeys: String, CodingKey {
        case email
        case fullName = "full_name"
        case sendEmail = "send_email"
    }
}

/// The candidate record echoed back by a successful invite. Every field is optional so a
/// 2xx response never fails to decode on an unexpected shape — the invite is what matters,
/// not parsing the echo.
public nonisolated struct InvitedCandidate: Decodable, Sendable {
    public let id: String?
    public let email: String?
}

/// The body sent when creating a user. Snake-case to match the API; blank optional
/// fields are omitted.
nonisolated struct CreateUserRequest: Encodable {
    let email: String
    let firstName: String?
    let lastName: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case email
        case firstName = "firstname"
        case lastName = "lastname"
        case role
    }
}

/// The user record echoed back by a successful create. All-optional so a 2xx never fails to
/// decode on an unexpected shape.
public nonisolated struct CreatedUser: Decodable, Sendable {
    public let id: String?
    public let email: String?
}

/// The body sent when creating a test.
nonisolated struct CreateTestRequest: Encodable {
    let name: String
}

/// The body sent when renaming a test.
nonisolated struct UpdateTestRequest: Encodable {
    let name: String
}

/// The test echoed back by a successful create/update/delete. All-optional so a 2xx
/// never fails to decode on an unexpected shape.
public nonisolated struct CreatedTest: Decodable, Sendable {
    public let id: String?
    public let name: String?
}

/// The body sent when creating a team.
nonisolated struct CreateTeamRequest: Encodable {
    let name: String
}

/// The body sent when adding a team member. Snake-case to match the API; a blank role
/// is omitted.
nonisolated struct AddTeamMemberRequest: Encodable {
    let email: String
    let role: String?
}

/// An empty JSON body (`{}`) for a write whose parameters are all in the path — a team-member
/// removal identifies the user in the URL.
nonisolated struct EmptyBody: Encodable {}

/// The team echoed back by a successful create. All-optional so a 2xx never fails to
/// decode on an unexpected shape.
public nonisolated struct CreatedTeam: Decodable, Sendable {
    public let id: String?
    public let name: String?
}

/// The record echoed back by a team-membership change. All-optional for the same
/// reason as the other write echoes.
public nonisolated struct TeamMembershipResult: Decodable, Sendable {
    public let id: String?
    public let email: String?
}

/// The body sent when creating a QuickPad interview.
nonisolated struct CreateQuickPadRequest: Encodable {
    let title: String?
    let quickpad: Bool
}

/// The body sent when scheduling an interview. The start time is an ISO-8601 string;
/// blank optional fields are omitted.
nonisolated struct ScheduleInterviewRequest: Encodable {
    let title: String
    let from: String
    let candidate: String?
    let notes: String?
}

/// The interview echoed back by a successful create. All-optional so a 2xx never fails
/// to decode on an unexpected shape; the URL lets a client open the new pad.
public nonisolated struct CreatedInterview: Decodable, Sendable {
    public let id: String?
    public let url: String?
    public let status: String?
}
