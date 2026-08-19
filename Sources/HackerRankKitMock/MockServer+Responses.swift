//
//  MockServer+Responses.swift
//  HackerRankKit
//
//  The fake API's request router: it maps a method + URL to a status and a canned
//  fixture body from ``MockFixtures``.
//

import Foundation

nonisolated enum MockResponses {
    /// The v3 API's path prefix, stripped before a route is matched by segment.
    private static let apiV3 = "/x/api/v3"

    /// Routes a request to its status code and JSON body. Writes (create/update/delete)
    /// are acknowledged with a canned record; reads return the matching fixture.
    static func respond(method: String, url: URL, query: [String: String] = [:]) -> (Int, Data) {
        if isNoContent(method: method, url: url) { return (204, Data()) }
        if method == "POST" || method == "PUT" || method == "PATCH" || method == "DELETE" {
            let status = method == "POST" ? 201 : 200
            return (status, Data(writeAckBody(for: url, method: method).utf8))
        }
        return (200, Data(body(for: url, query: query).utf8))
    }

    /// Whether the route is one the API documents as **204 No Content**. Answering these
    /// with a canned JSON record is what let the client's decode-after-success failures go
    /// unnoticed, so the fake returns the empty body the service actually returns.
    private static func isNoContent(method: String, url: URL) -> Bool {
        let path = url.path
        let stripped = path.hasPrefix(apiV3) ? String(path.dropFirst(apiV3.count)) : path
        let parts = stripped.split(separator: "/").map(String.init)
        switch method {
        case "POST":
            // POST /tests/{id}/archive
            return parts.count == 3 && parts[0] == "tests" && parts[2] == "archive"
        case "DELETE":
            // DELETE /tests/{id}, /users/{id}, and the SCIM /Users/{id} and /Groups/{id}.
            if parts.count == 2, ["tests", "users", "Users", "Groups"].contains(parts[0]) { return true }

            // DELETE /teams/{team_id}/users/{user_id}
            return parts.count == 4 && parts[0] == "teams" && parts[2] == "users"
        default:
            return false
        }
    }

    // MARK: - Read routing

    /// Picks the fixture for a request path. Candidate/search routes are checked first
    /// because their paths also contain another resource's segment.
    private static func body(for url: URL, query: [String: String]) -> String {
        let path = url.path
        if path == "/Users" { return MockFixtures.scimUsers }
        if path.hasPrefix("/Users/") { return MockFixtures.scimUser }
        if path == "/Groups" { return MockFixtures.scimGroups }
        if path.hasPrefix("/Groups/") { return MockFixtures.scimGroup }
        if path.hasSuffix("/search") { return searchBody(for: url, query: query) }
        if path.contains("/audit_log") { return MockFixtures.auditLog }
        if path.contains("/candidates") { return candidatesBody(path: path) }
        if path.hasSuffix("/inviters") { return MockFixtures.testInviters }
        if path.contains("/interview_templates") {
            return path.hasSuffix("/interview_templates")
                ? MockFixtures.interviewTemplates
                : MockFixtures.interviewTemplate
        }
        if path.contains("/templates") {
            return path.hasSuffix("/templates") ? MockFixtures.inviteTemplates : MockFixtures.inviteTemplate
        }
        if path.contains("/questions") {
            return path.hasSuffix("/questions") ? MockFixtures.questions : MockFixtures.questionDetail
        }
        if path.contains("/interviews") {
            return interviewSingleBody(path: path) ?? MockFixtures.interviews
        }
        if path.contains("/teams/") && path.contains("/users/") { return MockFixtures.teamMembership }
        if path.hasSuffix("/users/me") { return MockFixtures.currentUser }
        if path.contains("/users/") { return MockFixtures.singleUser }
        if path.contains("/users") { return MockFixtures.users }
        if path.contains("/teams/") { return MockFixtures.singleTeam }
        if path.contains("/teams") { return MockFixtures.teams }
        if path.contains("/tests") { return testsBody(for: url, query: query) }
        return #"{"data":[],"next":null}"#
    }

    /// The acknowledgement body for a write, routed by path. Order matters: `/users`
    /// precedes `/teams` because a membership path contains both, and `/candidates`
    /// precedes `/tests` because an invite path contains both.
    private static func writeAckBody(for url: URL, method: String) -> String {
        let path = url.path
        if path.hasPrefix("/Users") { return MockFixtures.scimUser }
        if path.hasPrefix("/Groups") { return MockFixtures.scimGroup }
        if path.contains("/ats") { return MockFixtures.atsInvite }
        if path.contains("/candidates") { return MockFixtures.createdCandidate }
        if path.contains("/teams") && path.contains("/users") { return MockFixtures.teamMembership }
        if path.contains("/interview_templates") {
            // A template delete answers with a message, not with the template record.
            return method == "DELETE" ? MockFixtures.deletedInterviewTemplate : MockFixtures.interviewTemplate
        }
        if path.contains("/users") { return MockFixtures.createdUser }
        if path.contains("/questions") {
            if path.hasSuffix("/generate") { return MockFixtures.generatedCodeStubs }

            return isQuestionOperation(path) ? MockFixtures.questionOperationResult : MockFixtures.writtenQuestion
        }
        if path.contains("/teams") { return MockFixtures.createdTeam }
        if path.contains("/interviews") { return MockFixtures.createdInterview }
        return MockFixtures.createdTest
    }

    /// Whether a question write targets a codestub or testcase sub-resource. Those
    /// endpoints echo a ``QuestionOperationResult`` status, not the question record.
    private static func isQuestionOperation(_ path: String) -> Bool {
        path.contains("/testcases") || path.contains("/custom_codestubs") || path.hasSuffix("/generate")
    }

    /// The `/tests` route: a single-test detail read for anything past the bare
    /// collection path, else the paginated tests list (page 2 when `offset=3`).
    private static func testsBody(for url: URL, query: [String: String]) -> String {
        if !url.path.hasSuffix("/tests") { return MockFixtures.testDetail }
        return query["offset"] == "3" ? MockFixtures.testsPage2 : MockFixtures.testsPage1
    }

    /// The candidates collection is paged, but `/tests/{test_id}/candidates/{candidate_id}`
    /// returns one candidate object.
    private static func candidatesBody(path: String) -> String {
        path.hasSuffix("/candidates") ? MockFixtures.candidates : MockFixtures.candidateDetail
    }

    /// Routes a single-interview read to its fixture — the transcript or the detail — or
    /// `nil` for the bare `/interviews` collection so the caller serves the list.
    private static func interviewSingleBody(path: String) -> String? {
        if path.hasSuffix("/transcript") { return MockFixtures.interviewTranscript }
        if !path.hasSuffix("/interviews") { return MockFixtures.interviewDetail }
        return nil
    }

    /// The candidate-search fixture for a path, or `nil` when the path is not a candidate
    /// search. The organisation-wide route answers with a different resource — a person and
    /// their attempts — from the per-test route's candidate records.
    private static func candidateSearchBase(for url: URL) -> String? {
        guard url.path.contains("/candidates") else { return nil }

        return url.path.contains("/tests/") ? MockFixtures.candidateSearch : MockFixtures.organizationCandidateSearch
    }

    /// Serves the server-side search endpoints (`/users/search`,
    /// `/tests/{id}/candidates/search`) so the demo actually narrows as you type. Filters
    /// the fixture's `data` rows to those with any string value containing the `search`
    /// term (case-insensitive) — a faithful stand-in for the server's own matching. An
    /// empty term returns the whole fixture.
    private static func searchBody(for url: URL, query: [String: String]) -> String {
        let base = candidateSearchBase(for: url) ?? MockFixtures.userSearch
        let needle = (query["search"] ?? query["query"] ?? "").lowercased()
        guard !needle.isEmpty,
              let data = base.data(using: .utf8),
              var envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = envelope["data"] as? [[String: Any]] else {
            return base
        }

        envelope["data"] = rows.filter { row in
            row.values.contains { ($0 as? String)?.lowercased().contains(needle) == true }
        }
        guard let out = try? JSONSerialization.data(withJSONObject: envelope),
              let json = String(bytes: out, encoding: .utf8) else { return base }

        return json
    }
}
