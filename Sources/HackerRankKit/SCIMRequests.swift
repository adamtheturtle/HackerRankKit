//
//  SCIMRequests.swift
//  HackerRankKit
//
//  The legacy SCIM provisioning surface (`/Users`, `/Groups`): its list envelope, the
//  user and group records, and the create/replace/patch bodies. Kept apart from the v3
//  wire models in `Requests.swift` because it is a separate, differently-shaped API that
//  happens to be reachable with the same credential.
//

import Foundation

/// A SCIM list response from the legacy `/Users` and `/Groups` provisioning endpoints.
public nonisolated struct SCIMListResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    public let resources: [Item]
    public let totalResults: Int?
    public let startIndex: Int?
    public let itemsPerPage: Int?

    enum CodingKeys: String, CodingKey {
        case resources = "Resources"
        case totalResults
        case startIndex
        case itemsPerPage
        case data
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decoded **leniently**, like `HackerRankPage`: the `try?` has to sit inside the array
        // so a single malformed row (a numeric `id` where `SCIMUser.id` is a `String?`, say) is
        // dropped on its own. Wrapping the whole array instead discards every good row too, so
        // a fully populated directory silently reads as empty.
        resources = (try? container.decode([LenientElement<Item>].self, forKey: .resources))?.compactMap(\.value)
            ?? ((try? container.decode([LenientElement<Item>].self, forKey: .data))?.compactMap(\.value) ?? [])
        totalResults = try? container.decodeIfPresent(Int.self, forKey: .totalResults)
        startIndex = try? container.decodeIfPresent(Int.self, forKey: .startIndex)
        itemsPerPage = try? container.decodeIfPresent(Int.self, forKey: .itemsPerPage)
    }
}

/// A user from the legacy SCIM `/Users` provisioning endpoints.
public nonisolated struct SCIMUser: Decodable, Identifiable, Sendable {
    public let id: String?
    public let userName: String?
    public let active: Bool?
    public let role: String?
    public let teamAdmin: Bool?
    public let companyAdmin: Bool?
    public let name: [String: HackerRankJSONValue]?
    public let emails: [HackerRankJSONValue]?
    public let schemas: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case userName
        case active
        case role
        case teamAdmin = "team_admin"
        case companyAdmin = "company_admin"
        case name
        case emails
        case schemas
    }
}

/// A group/team from the legacy SCIM `/Groups` provisioning endpoints.
public nonisolated struct SCIMGroup: Decodable, Identifiable, Sendable {
    public let id: String?
    public let displayName: String?
    public let members: [HackerRankJSONValue]?
    public let schemas: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case misspelledDisplayName = "diplayName"
        case members
        case schemas
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(String.self, forKey: .id)
        displayName = (try? container.decodeIfPresent(String.self, forKey: .displayName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .misspelledDisplayName))
        members = try? container.decodeIfPresent([HackerRankJSONValue].self, forKey: .members)
        schemas = try? container.decodeIfPresent([String].self, forKey: .schemas)
    }
}

/// The body sent when creating or replacing a legacy SCIM user.
///
/// `name`, `userName`, and `emails` are required by the create schema, so they are
/// parameters of the initializer rather than optionals: a body missing any of them is
/// rejected, and there is no reason to let one be built.
///
/// `emails` is stored as plain addresses for the Swift API, but encoded as SCIM
/// multi-valued objects (`{"value": …, "primary": …}`). The published create schema types
/// the field as `array<string>`, but the live SCIM service rejects that shape with HTTP 400.
public nonisolated struct SCIMUserWriteRequest: Encodable, Sendable, Equatable {
    public let userName: String
    public let name: [String: HackerRankJSONValue]
    public let emails: [String]
    public let active: Bool?
    public let role: String?
    public let teamAdmin: Bool?
    public let companyAdmin: Bool?
    public let schemas: [String]?

    enum CodingKeys: String, CodingKey {
        case userName
        case name
        case emails
        case active
        case role
        case teamAdmin = "team_admin"
        case companyAdmin = "company_admin"
        case schemas
    }

    private enum EmailKeys: String, CodingKey {
        case value
        case primary
    }

    /// - Parameters:
    ///   - userName: the SCIM user name, usually the primary email address.
    ///   - name: the name object, e.g. `["givenName": .string("Ada")]`.
    ///   - email: the user's primary email. Taking it separately from `additionalEmails`
    ///     is what guarantees the required list is never empty.
    ///   - additionalEmails: any further addresses, in order after the primary.
    public init(
        userName: String,
        name: [String: HackerRankJSONValue],
        email: String,
        additionalEmails: [String] = [],
        active: Bool? = nil,
        role: String? = nil,
        teamAdmin: Bool? = nil,
        companyAdmin: Bool? = nil,
        schemas: [String]? = nil
    ) {
        self.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name
        emails = [email.trimmingCharacters(in: .whitespacesAndNewlines)] + additionalEmails.compactMap(Self.nonBlank)
        self.active = active
        self.role = Self.nonBlank(role)
        self.teamAdmin = teamAdmin
        self.companyAdmin = companyAdmin
        self.schemas = Self.cleanList(schemas)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userName, forKey: .userName)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(teamAdmin, forKey: .teamAdmin)
        try container.encodeIfPresent(companyAdmin, forKey: .companyAdmin)
        try container.encodeIfPresent(schemas, forKey: .schemas)

        var emailsContainer = container.nestedUnkeyedContainer(forKey: .emails)
        for (index, address) in emails.enumerated() {
            var entry = emailsContainer.nestedContainer(keyedBy: EmailKeys.self)
            try entry.encode(address, forKey: .value)
            try entry.encode(index == 0, forKey: .primary)
        }
    }

    private static func cleanList(_ values: [String]?) -> [String]? {
        let cleaned = values?.compactMap(nonBlank)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// The body sent when creating or replacing a legacy SCIM group.
public nonisolated struct SCIMGroupWriteRequest: Encodable, Sendable, Equatable {
    public let displayName: String?
    public let members: [HackerRankJSONValue]?
    public let schemas: [String]?

    /// HackerRank's SCIM group schema spells the name key `diplayName`. Encoding the
    /// correctly spelled one meant the only name field the server reads was never sent.
    /// The response decoder already accepts both spellings.
    enum CodingKeys: String, CodingKey {
        case displayName = "diplayName"
        case members
        case schemas
    }

    public init(
        displayName: String? = nil,
        members: [HackerRankJSONValue]? = nil,
        schemas: [String]? = nil
    ) {
        self.displayName = Self.nonBlank(displayName)
        self.members = members?.isEmpty == false ? members : nil
        self.schemas = Self.cleanList(schemas)
    }

    private static func cleanList(_ values: [String]?) -> [String]? {
        let cleaned = values?.compactMap(nonBlank)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// The body sent for legacy SCIM PATCH operations.
public nonisolated struct SCIMPatchRequest: Encodable, Sendable, Equatable {
    public let schemas: [String]?
    public let operations: [SCIMPatchOperation]

    enum CodingKeys: String, CodingKey {
        case schemas
        case operations = "Operations"
    }

    public init(
        operations: [SCIMPatchOperation],
        schemas: [String]? = ["urn:ietf:params:scim:api:messages:2.0:PatchOp"]
    ) {
        self.operations = operations
        self.schemas = schemas?.isEmpty == false ? schemas : nil
    }
}

/// One operation in a legacy SCIM PATCH request.
public nonisolated struct SCIMPatchOperation: Encodable, Sendable, Equatable {
    public let op: String
    public let path: String?
    public let value: HackerRankJSONValue?

    public init(op: String, path: String? = nil, value: HackerRankJSONValue? = nil) {
        self.op = op.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = path?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.path = trimmedPath?.isEmpty == false ? trimmedPath : nil
        self.value = value
    }
}
