//
//  MockServer+Responses.swift
//  HackerRankKit
//
//  The fake API's request router: an explicit table of the routes HackerRank exposes,
//  each mapped to a status and a canned fixture body from ``MockFixtures``.
//
//  The table is the point. A router that fell through to a generic success accepted
//  typos, removed endpoints, and wrong HTTP methods, so a request-routing regression
//  passed its tests against the fake and failed only in production. Anything not
//  declared here answers 404, and a path declared for other methods answers 405.
//

import Foundation

nonisolated enum MockResponses {
    /// One route the fake serves: a method, a path pattern, and the response to give.
    ///
    /// A pattern segment of `*` matches any single path segment, so `tests/*/candidates`
    /// stands for `/x/api/v3/tests/{test_id}/candidates`.
    private struct Route: Sendable {
        let method: String
        let pattern: [String]
        let respond: @Sendable (URL, [String: String]) -> (Int, String)

        init(_ method: String, _ path: String, status: Int = 200, body: @escaping @Sendable () -> String) {
            self.init(method, path) { _, _ in (status, body()) }
        }

        init(
            _ method: String,
            _ path: String,
            respond: @escaping @Sendable (URL, [String: String]) -> (Int, String)
        ) {
            self.method = method
            pattern = path.split(separator: "/").map(String.init)
            self.respond = respond
        }

        nonisolated func matches(_ segments: [String]) -> Bool {
            guard pattern.count == segments.count else { return false }

            return zip(pattern, segments).allSatisfy { $0 == "*" || $0 == $1 }
        }
    }

    /// The v3 API's path prefix, which every route below is relative to except SCIM's.
    private static let apiV3 = "/x/api/v3"

    /// Routes a request to its status code and JSON body, or to 404/405 when the route is
    /// not one the API exposes.
    static func respond(method: String, url: URL, query: [String: String] = [:]) -> (Int, Data) {
        let segments = url.path.split(separator: "/").map(String.init)
        guard let route = routes.first(where: { $0.method == method && $0.matches(segments) }) else {
            let pathExists = routes.contains { $0.matches(segments) }
            let message = pathExists
                ? #"{"error":"Method not allowed"}"#
                : #"{"error":"Not found"}"#
            return (pathExists ? 405 : 404, Data(message.utf8))
        }

        let (status, body) = route.respond(url, query)
        return (status, Data(body.utf8))
    }

    /// Every route the fake serves, in match order: a path with a literal segment is
    /// declared before the wildcard route it would otherwise be swallowed by
    /// (`/users/me` before `/users/{id}`, `/testcases/delete_all` before
    /// `/testcases/{id}`).
    private static let routes: [Route] = scimRoutes + testRoutes + candidateRoutes + questionRoutes
        + interviewRoutes + templateRoutes + userRoutes + teamRoutes + [
            Route("GET", "\(apiV3)/audit_log") { MockFixtures.auditLog },
            Route("POST", "\(apiV3)/ats/codepair", status: 201) { MockFixtures.atsInvite },
            Route("POST", "\(apiV3)/ats/codescreen", status: 201) { MockFixtures.atsInvite }
        ]

    /// The legacy SCIM provisioning routes. Their deletes are 204 No Content.
    private static let scimRoutes: [Route] = [
        Route("GET", "/Users") { MockFixtures.scimUsers },
        Route("POST", "/Users", status: 201) { MockFixtures.scimUser },
        Route("GET", "/Users/*") { MockFixtures.scimUser },
        Route("PUT", "/Users/*") { MockFixtures.scimUser },
        Route("PATCH", "/Users/*") { MockFixtures.scimUser },
        Route("DELETE", "/Users/*", status: 204) { "" },
        Route("GET", "/Groups") { MockFixtures.scimGroups },
        Route("POST", "/Groups", status: 201) { MockFixtures.scimGroup },
        Route("GET", "/Groups/*") { MockFixtures.scimGroup },
        Route("PATCH", "/Groups/*") { MockFixtures.scimGroup },
        Route("DELETE", "/Groups/*", status: 204) { "" }
    ]

    private static let testRoutes: [Route] = [
        Route("GET", "\(apiV3)/tests") { _, query in
            // Page two is served at the offset the first page's `next` cursor names.
            (200, query["offset"] == "3" ? MockFixtures.testsPage2 : MockFixtures.testsPage1)
        },
        Route("POST", "\(apiV3)/tests", status: 201) { MockFixtures.createdTest },
        Route("POST", "\(apiV3)/tests/*/archive", status: 204) { "" },
        Route("GET", "\(apiV3)/tests/*/inviters") { MockFixtures.testInviters },
        Route("GET", "\(apiV3)/tests/*") { MockFixtures.testDetail },
        Route("PUT", "\(apiV3)/tests/*") { MockFixtures.createdTest },
        Route("DELETE", "\(apiV3)/tests/*", status: 204) { "" }
    ]

    private static let candidateRoutes: [Route] = [
        Route("GET", "\(apiV3)/candidates/search") { url, query in
            (200, search(MockFixtures.organizationCandidateSearch, url: url, query: query))
        },
        Route("GET", "\(apiV3)/tests/*/candidates/search") { url, query in
            (200, search(MockFixtures.candidateSearch, url: url, query: query))
        },
        Route("GET", "\(apiV3)/tests/*/candidates") { MockFixtures.candidates },
        Route("POST", "\(apiV3)/tests/*/candidates", status: 201) { MockFixtures.createdCandidate },
        Route("GET", "\(apiV3)/tests/*/candidates/*/pdf") { MockFixtures.candidateDetail },
        Route("DELETE", "\(apiV3)/tests/*/candidates/*/report") { MockFixtures.createdCandidate },
        Route("DELETE", "\(apiV3)/tests/*/candidates/*/invite") { MockFixtures.createdCandidate },
        Route("GET", "\(apiV3)/tests/*/candidates/*") { MockFixtures.candidateDetail },
        Route("PUT", "\(apiV3)/tests/*/candidates/*") { MockFixtures.createdCandidate }
    ]

    private static let questionRoutes: [Route] = [
        Route("GET", "\(apiV3)/questions") { MockFixtures.questions },
        Route("POST", "\(apiV3)/questions", status: 201) { MockFixtures.writtenQuestion },
        Route("PUT", "\(apiV3)/questions/*/generate") { MockFixtures.generatedCodeStubs },
        Route("PUT", "\(apiV3)/questions/*/custom_codestubs") { MockFixtures.questionOperationResult },
        Route("POST", "\(apiV3)/questions/*/testcases", status: 201) { MockFixtures.questionOperationResult },
        Route("DELETE", "\(apiV3)/questions/*/testcases/delete_all") { MockFixtures.questionOperationResult },
        Route("PUT", "\(apiV3)/questions/*/testcases/*") { MockFixtures.questionOperationResult },
        Route("DELETE", "\(apiV3)/questions/*/testcases/*") { MockFixtures.questionOperationResult },
        Route("GET", "\(apiV3)/questions/*") { MockFixtures.questionDetail },
        Route("PUT", "\(apiV3)/questions/*") { MockFixtures.writtenQuestion }
    ]

    private static let interviewRoutes: [Route] = [
        Route("GET", "\(apiV3)/interviews") { MockFixtures.interviews },
        Route("POST", "\(apiV3)/interviews", status: 201) { MockFixtures.createdInterview },
        Route("GET", "\(apiV3)/interviews/*/transcript") { MockFixtures.interviewTranscript },
        Route("GET", "\(apiV3)/interviews/*") { MockFixtures.interviewDetail },
        Route("PUT", "\(apiV3)/interviews/*") { MockFixtures.createdInterview },
        Route("DELETE", "\(apiV3)/interviews/*") { MockFixtures.createdInterview }
    ]

    private static let templateRoutes: [Route] = [
        Route("GET", "\(apiV3)/interview_templates") { MockFixtures.interviewTemplates },
        Route("POST", "\(apiV3)/interview_templates", status: 201) { MockFixtures.interviewTemplate },
        Route("GET", "\(apiV3)/interview_templates/*") { MockFixtures.interviewTemplate },
        // Sharing is its own pair of endpoints; the deprecated `team_share` field does nothing.
        Route("POST", "\(apiV3)/interview_templates/*/explicit_sharing_roles/update_access") {
            MockFixtures.interviewTemplateSharing
        },
        Route("DELETE", "\(apiV3)/interview_templates/*/explicit_sharing_roles/remove_access") {
            MockFixtures.interviewTemplateSharing
        },
        Route("PUT", "\(apiV3)/interview_templates/*") { MockFixtures.interviewTemplate },
        // A template delete answers with a message, not with the template record.
        Route("DELETE", "\(apiV3)/interview_templates/*") { MockFixtures.deletedInterviewTemplate },
        Route("GET", "\(apiV3)/templates") { MockFixtures.inviteTemplates },
        Route("GET", "\(apiV3)/templates/*") { MockFixtures.inviteTemplate }
    ]

    private static let userRoutes: [Route] = [
        Route("GET", "\(apiV3)/users") { MockFixtures.users },
        Route("POST", "\(apiV3)/users", status: 201) { MockFixtures.createdUser },
        Route("GET", "\(apiV3)/users/me") { MockFixtures.currentUser },
        Route("GET", "\(apiV3)/users/search") { url, query in
            (200, search(MockFixtures.userSearch, url: url, query: query))
        },
        Route("GET", "\(apiV3)/users/*") { MockFixtures.singleUser },
        Route("PUT", "\(apiV3)/users/*") { MockFixtures.singleUser },
        Route("DELETE", "\(apiV3)/users/*", status: 204) { "" }
    ]

    private static let teamRoutes: [Route] = [
        Route("GET", "\(apiV3)/teams") { MockFixtures.teams },
        Route("POST", "\(apiV3)/teams", status: 201) { MockFixtures.createdTeam },
        Route("GET", "\(apiV3)/teams/*/users") { MockFixtures.users },
        Route("GET", "\(apiV3)/teams/*/users/*") { MockFixtures.teamMembership },
        Route("POST", "\(apiV3)/teams/*/users/*", status: 201) { MockFixtures.teamMembership },
        Route("DELETE", "\(apiV3)/teams/*/users/*", status: 204) { "" },
        Route("GET", "\(apiV3)/teams/*") { MockFixtures.singleTeam },
        Route("PUT", "\(apiV3)/teams/*") { MockFixtures.singleTeam },
        Route("DELETE", "\(apiV3)/teams/*") { MockFixtures.createdTeam }
    ]

    /// Filters a search fixture's `data` rows to those with any string value containing the
    /// search term (case-insensitive) — a faithful stand-in for the server's own matching,
    /// so the demo actually narrows as you type. An empty term returns the whole fixture.
    private static func search(_ base: String, url _: URL, query: [String: String]) -> String {
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
