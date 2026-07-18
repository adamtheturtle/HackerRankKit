//
//  HackerRankClient+AuditLog.swift
//  HackerRankKit
//

import Foundation
import PaginatedRESTClient

extension HackerRankClient {
    /// One page of the organisation's audit log (`GET /audit_log`) — the server-side change
    /// history (who changed what, when, from where), optionally scoped to a single `userID`.
    /// Follows the absolute `next` cursor for subsequent pages, like the other lists.
    public func auditLogPage(after cursor: String? = nil, userID: String? = nil) async throws
        -> Page<AuditLogEntry> {
        let url = try auditLogURL(cursor: cursor, userID: userID)
        let response = try await rest.performWithRetry(
            HackerRankPage<AuditLogEntry>.self,
            request: rest.authorizedGET(url)
        )
        return Page(items: response.data, next: response.next, totalCount: response.totalCount)
    }

    /// The absolute `cursor` URL when continuing, or the first-page URL (base + path + `limit`,
    /// plus an optional `user_id` filter) when starting.
    private func auditLogURL(cursor: String?, userID: String?) throws -> URL {
        if let cursor {
            guard let url = cursorURL(cursor) else {
                throw HackerRankError.http(0, "Invalid next-page URL: \(cursor)")
            }

            return url
        }

        var query = [URLQueryItem(name: "limit", value: String(Self.pageSize))]
        if let userID, !userID.isEmpty {
            query.append(URLQueryItem(name: "user_id", value: userID))
        }
        return try url(path: "\(Self.apiV3)/audit_log", query: query)
    }
}
