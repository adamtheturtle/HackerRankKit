//
//  AuditLogEntry.swift
//  HackerRankKit
//

import Foundation

/// One entry in the organisation's server-side audit log (`GET /audit_log` → `AuditLogShow`):
/// who changed what, when, and from where. This is the org's actual change history.
///
/// Every field is optional and decoded resiliently so a 2xx response never fails on a shape that
/// varies by `source_type`. `source_id` is accepted as either a string or a number, and `user`
/// as either a bare string or a `{ email, firstname, lastname }` object (via `InterviewPerson`,
/// the shared lenient person decoder).
public nonisolated struct AuditLogEntry: Decodable, Hashable, Identifiable, Sendable {
    /// Identifier of the changed resource.
    public let sourceID: String?
    /// The kind of resource changed (e.g. "test", "user", "team").
    public let sourceType: String?
    /// A display label for the user who made the change, if known.
    public let userLabel: String?
    /// The action performed (e.g. "create", "update", "delete").
    public let action: String?
    /// The names of the fields that changed.
    public let modifiedFields: [String]
    /// The originating IP address, if recorded.
    public let ipAddress: String?
    /// ISO-8601 timestamp of the change.
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case sourceType = "source_type"
        case user
        case action
        case modifiedFields = "modified_fields"
        case ipAddress = "ip_address"
        case createdAt = "created_at"
    }

    /// A stable identity built from the fields that together pin one entry, since the log has no
    /// dedicated id. Good enough to keep rows distinct in a list.
    public var id: String {
        "\(sourceType ?? "")-\(sourceID ?? "")-\(action ?? "")-\(createdAt ?? "")"
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceID = Self.flexibleString(container, .sourceID)
        sourceType = container.loggedDecodeIfPresent(String.self, forKey: .sourceType)
        action = container.loggedDecodeIfPresent(String.self, forKey: .action)
        modifiedFields = (container.loggedDecodeIfPresent([String].self, forKey: .modifiedFields)) ?? []
        ipAddress = container.loggedDecodeIfPresent(String.self, forKey: .ipAddress)
        createdAt = container.loggedDecodeIfPresent(String.self, forKey: .createdAt)
        userLabel = (container.loggedDecodeIfPresent(InterviewPerson.self, forKey: .user))?.displayName
    }

    /// Decodes a key that may arrive as either a JSON string or a number, returning its string
    /// form either way (`source_id` is documented as a string but live records sometimes carry
    /// a numeric id).
    private static func flexibleString(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let string = container.loggedDecodeIfPresent(String.self, forKey: key) { return string }
        if let number = container.loggedDecodeIfPresent(Int.self, forKey: key) { return String(number) }
        return nil
    }
}

extension AuditLogEntry {
    /// A one-line summary of the change, e.g. "Updated test t1".
    public var headline: String {
        let verb = (action ?? "changed").capitalized
        let type = sourceType ?? "record"
        if let sourceID, !sourceID.isEmpty {
            return "\(verb) \(type) \(sourceID)"
        }
        return "\(verb) \(type)"
    }

    /// An SF Symbol name reflecting the action.
    public var actionSymbol: String {
        switch action?.lowercased() {
        case "create", "created": "plus.circle"
        case "delete", "deleted", "destroy", "destroyed": "trash"
        case "update", "updated", "edit", "edited": "pencil"
        default: "circle"
        }
    }
}
