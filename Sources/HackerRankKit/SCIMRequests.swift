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
public nonisolated struct SCIMUserWriteRequest: Encodable, Sendable, Equatable {
    public let userName: String?
    public let active: Bool?
    public let role: String?
    public let teamAdmin: Bool?
    public let companyAdmin: Bool?
    public let name: [String: HackerRankJSONValue]?
    public let emails: [HackerRankJSONValue]?
    public let schemas: [String]?

    enum CodingKeys: String, CodingKey {
        case userName
        case active
        case role
        case teamAdmin = "team_admin"
        case companyAdmin = "company_admin"
        case name
        case emails
        case schemas
    }

    public init(
        userName: String? = nil,
        active: Bool? = nil,
        role: String? = nil,
        teamAdmin: Bool? = nil,
        companyAdmin: Bool? = nil,
        name: [String: HackerRankJSONValue]? = nil,
        emails: [HackerRankJSONValue]? = nil,
        schemas: [String]? = nil
    ) {
        self.userName = Self.nonBlank(userName)
        self.active = active
        self.role = Self.nonBlank(role)
        self.teamAdmin = teamAdmin
        self.companyAdmin = companyAdmin
        self.name = name?.isEmpty == false ? name : nil
        self.emails = emails?.isEmpty == false ? emails : nil
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

/// The body sent when creating or replacing a legacy SCIM group.
public nonisolated struct SCIMGroupWriteRequest: Encodable, Sendable, Equatable {
    public let displayName: String?
    public let members: [HackerRankJSONValue]?
    public let schemas: [String]?

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
