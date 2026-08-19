//
//  HackerRankClient+Search.swift
//  HackerRankKit
//

import Foundation
import PaginatedRESTClient

extension HackerRankClient {
    /// Searches the organisation's users **server-side** (`GET /users/search?search=`).
    ///
    /// The v3 API exposes a free-text user search, so a large org (thousands of members) can be
    /// searched by the server rather than by loading the whole list and filtering loaded rows.
    /// Returns a paged envelope in the same shape as the `/users` list, so the cursor-following
    /// pattern is identical.
    public func searchUsers(query: String, after cursor: String? = nil) async throws -> Page<User> {
        try await searchPage(
            HackerRankPage<User>.self,
            path: "\(Self.apiV3)/users/search",
            query: query,
            cursor: cursor
        )
    }

    /// Searches candidates across the organisation (`GET /candidates/search?query=`).
    ///
    /// This endpoint answers with ``CandidateSearchResult`` rows — a person plus every test
    /// attempt of theirs the caller can see — not with the per-test ``TestCandidate``
    /// records the other searches return. Decoding them as `TestCandidate` required an `id`
    /// the rows do not have, so the lenient page decoder discarded every match and the
    /// search always looked empty.
    public func searchCandidates(query: String, after cursor: String? = nil) async throws
        -> Page<CandidateSearchResult> {
        try await searchPage(
            HackerRankPage<CandidateSearchResult>.self,
            path: "\(Self.apiV3)/candidates/search",
            queryItemName: "query",
            query: query,
            cursor: cursor
        )
    }

    /// Searches a test's candidates **server-side** (`GET /tests/{id}/candidates/search?search=`).
    /// Returns the same paged shape as the `/candidates` list, so for a test with many candidates
    /// a match deep in the list is reachable rather than limited to loaded rows.
    public func searchCandidates(testID: String, query: String, after cursor: String? = nil) async throws
        -> Page<TestCandidate> {
        try await searchPage(
            HackerRankPage<TestCandidate>.self,
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/search",
            query: query,
            cursor: cursor
        )
    }

    /// Fetches one page of a server-side search: the first page (base + path + `search` + `limit`)
    /// when `cursor` is `nil`, or the absolute `next` cursor URL otherwise (which already carries
    /// the search term). Mirrors `HackerRankClient.page`, kept here because that funnel is private
    /// to its file, per the split-file rule.
    private func searchPage<Item: Decodable & Sendable>(
        _: HackerRankPage<Item>.Type,
        path: String,
        queryItemName: String = "search",
        query: String,
        cursor: String?
    ) async throws -> Page<Item> {
        let url = try searchURL(path: path, queryItemName: queryItemName, query: query, cursor: cursor)
        let response = try await rest.performWithRetry(HackerRankPage<Item>.self, request: try authorizedGET(url))
        return Page(items: response.data, next: response.next, totalCount: response.totalCount)
    }

    private func searchURL(
        path: String, queryItemName: String = "search", query: String, cursor: String?
    ) throws -> URL {
        if let cursor {
            guard let url = cursorURL(cursor) else {
                throw HackerRankError.http(0, "Invalid next-page URL: \(cursor)")
            }

            return url
        }

        // Built through `url(path:query:)` so the search term is percent-encoded by
        // `queryComponent`, which — unlike `URLComponents` — escapes `+`. The API's
        // Rack/Rails query parser turns a literal `+` into a space, so `C++` and
        // plus-addressed emails would otherwise be searched for as something else.
        return try url(path: path, query: [
            URLQueryItem(name: queryItemName, value: query),
            URLQueryItem(name: "limit", value: String(Self.pageSize))
        ])
    }
}
