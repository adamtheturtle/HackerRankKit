import Foundation
import PaginatedRESTClient

/// Filters shared by offset and initial cursor audit requests.
public nonisolated struct AuditLogFilters: Sendable {
    public var user: String?
    public var sourceType: String?
    public var sourceID: String?
    public var createdAt: String?
    public var sort: String?
    public var expand: String?

    public init(user: String? = nil, sourceType: String? = nil, sourceID: String? = nil,
                createdAt: String? = nil, sort: String? = nil, expand: String? = nil) {
        self.user = user
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.createdAt = createdAt
        self.sort = sort
        self.expand = expand
    }

    func queryItems() throws -> [URLQueryItem] {
        if sourceID != nil && sourceType == nil {
            throw HackerRankError.http(0, "source_type is required with source_id")
        }
        return ["user": user, "source_type": sourceType, "source_id": sourceID,
                "created_at": createdAt, "sort": sort, "expand": expand]
            .compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
    }
}

/// A cursor page. Its token is opaque and expires after inactivity; it is not a URL.
public nonisolated struct AuditLogCursorPage: Decodable, Sendable {
    public let data: [AuditLogEntry]
    public let pageTotal: Int
    public let hasMore: Bool
    public let nextCursor: String?
    public let total: Int?

    enum CodingKeys: String, CodingKey {
        case data, pageTotal = "page_total", hasMore = "has_more", nextCursor = "next_cursor", total
    }
}

/// Offset pagination including the server's reachable-window metadata.
public nonisolated struct AuditLogOffsetPage: Decodable, Sendable {
    public let data: [AuditLogEntry]
    public let next: String?
    public let offsetWindowLimit: Int?
    public let offsetWindowExhausted: Bool?

    enum CodingKeys: String, CodingKey {
        case data, next, offsetWindowLimit = "offset_window_limit", offsetWindowExhausted = "offset_window_exhausted"
    }
}

extension HackerRankClient {
    /// Continues with only cursor; initial filters, sorting and expansion stay in the server snapshot.
    public func auditLogCursorPage(cursor: String? = nil, filters: AuditLogFilters = AuditLogFilters(),
                                   includeTotal: Bool? = nil) async throws -> AuditLogCursorPage {
        var query: [URLQueryItem]
        if let cursor {
            query = [URLQueryItem(name: "cursor", value: cursor)]
        } else {
            query = try filters.queryItems()
            if let includeTotal { query.append(URLQueryItem(name: "include_total", value: String(includeTotal))) }
        }
        return try await fetch(AuditLogCursorPage.self, path: "\(Self.apiV3)/audit_log/cursor", query: query)
    }

    /// Offset access with current filters and explicit window exhaustion metadata.
    public func auditLogOffsetPage(limit: Int = 100, offset: Int = 0,
                                   filters: AuditLogFilters = AuditLogFilters()) async throws -> AuditLogOffsetPage {
        let query = try filters.queryItems() + [URLQueryItem(name: "limit", value: String(limit)),
                                                URLQueryItem(name: "offset", value: String(offset))]
        return try await fetch(AuditLogOffsetPage.self, path: "\(Self.apiV3)/audit_log", query: query)
    }
}
