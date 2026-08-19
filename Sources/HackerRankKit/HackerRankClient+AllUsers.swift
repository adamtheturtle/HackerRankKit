//
//  HackerRankClient+AllUsers.swift
//  HackerRankKit
//

import Foundation
import PaginatedRESTClient

extension HackerRankClient {
    /// Loads the organisation's users as one list by fetching every page **in parallel** by offset.
    /// People is bounded — an org has thousands of members, not the tens of thousands of
    /// interviews — and the API exposes no name-search parameter, so loading the whole list is
    /// what lets People search match any user by name or email instead of only the first page. The
    /// first page gives the `total`; the rest are fetched concurrently (bounded, to stay gentle on
    /// the rate limiter) and reassembled in offset order. At most `maxUsers` users are returned,
    /// so a pathologically huge org can't drain unbounded; if `total` is absent it returns just
    /// the first page.
    public func allUsers(maxUsers: Int = 6000) async throws -> [User] {
        guard maxUsers > 0 else { return [] }

        let path = "\(Self.apiV3)/users"
        let first = try await offsetUsersPage(path: path, offset: 0)
        var all = first.data
        // The bound is decided by the envelope's `total`, never by how many rows decoded.
        // `HackerRankPage` drops individually malformed rows, so a first page that decodes
        // to nothing does not mean the collection is empty — guarding on that abandoned
        // every later offset even when the server reported thousands more users.
        let total = min(first.totalCount ?? all.count, maxUsers)
        guard total > Self.pageSize else { return Array(all.prefix(maxUsers)) }

        // Offsets step by the page size we *requested*, never by how many records decoded.
        // `HackerRankPage` drops individually malformed rows, so `all.count` can be short of
        // the page the server actually returned — and the server offsets by `limit`. Deriving
        // the stride from the decoded count would shift every subsequent offset backwards and
        // re-request records already held, duplicating ids in an `Identifiable` list.
        let offsets = Array(stride(from: Self.pageSize, to: total, by: Self.pageSize))
        var byOffset: [Int: [User]] = [:]
        var pending = offsets[...]
        try await withThrowingTaskGroup(of: (Int, [User]).self) { group in
            func enqueueNext() {
                guard let offset = pending.first else { return }

                pending = pending.dropFirst()
                group.addTask { [self] in try await (offset, offsetUsersPage(path: path, offset: offset).data) }
            }
            for _ in 0 ..< 5 {
                enqueueNext()
            } // up to 5 pages in flight at once
            while let (offset, users) = try await group.next() {
                byOffset[offset] = users
                enqueueNext()
            }
        }
        for offset in offsets {
            all += byOffset[offset] ?? []
        }
        // `maxUsers` is a hard bound on what is returned, not just on which offsets are
        // requested: pages arrive whole, so the last one fetched routinely overshoots it.
        return Array(all.prefix(maxUsers))
    }

    /// Fetches one users page at an explicit `offset` (for the parallel `allUsers` fan-out).
    private func offsetUsersPage(path: String, offset: Int) async throws -> HackerRankPage<User> {
        let url = try url(path: path, query: [
            URLQueryItem(name: "limit", value: String(Self.pageSize)),
            URLQueryItem(name: "offset", value: String(offset))
        ])
        return try await rest.performWithRetry(HackerRankPage<User>.self, request: try authorizedGET(url))
    }
}
