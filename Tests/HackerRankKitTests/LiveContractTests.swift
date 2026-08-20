//
//  LiveContractTests.swift
//  HackerRankKitTests
//
//  Checks the modelled wire contract against a real HackerRank account.
//
//  Every other test in this suite proves the client agrees with the mock, and the mock
//  agrees with the published schema. Neither proves the schema describes what the service
//  actually sends — and in several places the schema contradicts itself, so the package
//  had to choose. These tests make that choice falsifiable.
//
//  Run with a personal access token:
//
//      HACKERRANK_TOKEN=… swift test --filter "Live wire contract"
//
//  They are skipped entirely without one, so CI is unaffected. **Read-only**: every
//  request is a GET. Nothing here creates, updates, deletes, or invites, so it is safe to
//  point at a production account. The token is read from the environment and never
//  written anywhere.
//

import Foundation
@testable import HackerRankKit
import Testing

/// The account under test, and the raw-JSON access these checks need: the point is to
/// compare what the server sent against what the model kept, which the typed client
/// cannot show on its own.
enum LiveAccount {
    /// The suite's `.enabled(if:)` trait evaluates in a Sendable closure, so the two
    /// properties it needs are nonisolated; the rest stay on the main actor with the tests.
    nonisolated static var token: String? {
        let value = ProcessInfo.processInfo.environment["HACKERRANK_TOKEN"]
        return value?.isEmpty == false ? value : nil
    }

    /// Whether a token is configured. The live suite is skipped when it is not.
    nonisolated static var isConfigured: Bool {
        token != nil
    }

    static var baseURL: URL {
        ProcessInfo.processInfo.environment["HACKERRANK_BASE_URL"]
            .flatMap(URL.init(string:)) ?? HackerRankClient.defaultBaseURL
    }

    static func client() -> HackerRankClient {
        HackerRankClient(token: token ?? "", baseURL: baseURL)
    }

    /// GETs `path` and returns the parsed JSON, so a check can ask what the server sent
    /// rather than what the model kept. Read-only by construction.
    static func rawJSON(path: String, query: [URLQueryItem] = []) async throws -> [String: Any] {
        let client = client()
        var request = URLRequest(url: try client.url(path: path, query: query))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(status) else {
            throw HackerRankError.http(status, String(data: data, encoding: .utf8) ?? "")
        }

        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// The first row of a paged response, for the checks that need one real record.
    static func firstRow(path: String, query: [URLQueryItem] = []) async throws -> [String: Any]? {
        let envelope = try await rawJSON(path: path, query: query)
        return (envelope["data"] as? [[String: Any]])?.first
    }

    /// A short name for a JSON value's type, so a shape check can report what arrived.
    static func kind(of value: Any?) -> String {
        switch value {
        case nil, is NSNull: "null/absent"
        case let array as [Any]: array.first.map { "array of \(kind(of: $0))" } ?? "empty array"
        case is [String: Any]: "object"
        case let number as NSNumber: CFGetTypeID(number) == CFBooleanGetTypeID() ? "bool" : "number"
        case is String: "string"
        default: "unknown"
        }
    }

    /// Reports a shape the package had to guess at. Never fails: the value of running this
    /// is the report, and a guess that turns out wrong is a finding, not a broken test.
    static func report(_ field: String, expected: String, actual: String) {
        let verdict = expected == actual ? "OK    " : "DIFFERS"
        print("[live] \(verdict) \(field): modelled as \(expected), server sent \(actual)")
    }
}

/// The checks behind issue #197. Skipped unless `HACKERRANK_TOKEN` is set.
@Suite("Live wire contract", .enabled(if: LiveAccount.isConfigured))
struct LiveContractTests {
    private let client = LiveAccount.client()
    private let apiV3 = "/x/api/v3"

    // MARK: The keys that were misspelled before 0.8.0

    @Test
    func `an assessment's window decodes from the keys the server sends`() async throws {
        let page = try await client.testsPage()
        guard let test = page.items.first else {
            print("[live] SKIP  no tests on this account")
            return
        }

        let row = try await LiveAccount.firstRow(path: "\(apiV3)/tests")
        // Before 0.8.0 these read `start_time`/`end_time` and were always nil.
        LiveAccount.report("Test.starttime", expected: "string", actual: LiveAccount.kind(of: row?["starttime"]))
        LiveAccount.report("Test.endtime", expected: "string", actual: LiveAccount.kind(of: row?["endtime"]))
        if row?["starttime"] is String {
            #expect(test.startTime != nil, "the server sent `starttime` but the model dropped it")
        }
        #expect(row?["start_time"] == nil, "`start_time` exists after all — the model should read it")
    }

    @Test
    func `a test's sections arrive in the shape the model accepts`() async throws {
        // Documented only as "Section slot data for the test", with no value shape. The
        // model accepts an object keyed by slot and an array; this says which is real.
        let rows = await (try LiveAccount.rawJSON(path: "\(apiV3)/tests")["data"] as? [[String: Any]]) ?? []
        guard let sections = rows.compactMap({ $0["sections"] }).first(where: { !($0 is NSNull) }) else {
            print("[live] SKIP  no test on this account has sections")
            return
        }

        LiveAccount.report("Test.sections", expected: "object", actual: LiveAccount.kind(of: sections))
        if let object = sections as? [String: Any], let slot = object.values.first {
            LiveAccount.report("Test.sections[slot]", expected: "object", actual: LiveAccount.kind(of: slot))
        }
        #expect(sections is [String: Any] || sections is [Any], "sections is a shape the model cannot read")
    }

    // MARK: The candidate fields whose type the schema contradicts

    @Test
    func `a candidate's attempt events and question scores match their models`() async throws {
        guard let context = try await firstCandidate() else {
            print("[live] SKIP  no candidate on this account")
            return
        }

        let path = "\(apiV3)/tests/\(context.testID)/candidates/\(context.candidateID)"
        let raw = try await LiveAccount.rawJSON(
            path: path,
            query: HackerRankClient.additionalFieldsQuery(TestCandidate.detailAdditionalFields)
        )

        // The schema types `attempt_events` as an array of strings while describing each
        // entry as an object. The model accepts either; this says which it is.
        LiveAccount.report(
            "TestCandidate.attempt_events",
            expected: "array of object",
            actual: LiveAccount.kind(of: raw["attempt_events"])
        )
        // `questions` is typed `object` with a `$ref` to a single QuestionScore. The model
        // assumes it is keyed by question id.
        LiveAccount.report(
            "TestCandidate.questions", expected: "object", actual: LiveAccount.kind(of: raw["questions"])
        )

        let candidate = try await client.candidate(testID: context.testID, candidateID: context.candidateID)
        if raw["questions"] is [String: Any] {
            #expect(candidate.questionScores?.isEmpty == false, "the server sent `questions` but the model kept none")
        }
        if let events = raw["attempt_events"] as? [Any], !events.isEmpty {
            #expect(candidate.attemptEvents?.isEmpty == false, "the server sent events but the model kept none")
        }
    }

    // MARK: Fields the package added in 0.8.0, which should now be arriving

    @Test
    func `the documented fields the models gained are actually populated`() async throws {
        // A modelled property that is nil on every record is either genuinely unset on
        // this account or a key that still does not match. Reporting them is what makes
        // the difference visible.
        let users = try await client.usersPage()
        if let user = users.items.first {
            let row = try await LiveAccount.firstRow(path: "\(apiV3)/users")
            for key in ["phone", "timezone", "questions_permission", "shared_tests_permission"] {
                LiveAccount.report("User.\(key)", expected: "present", actual: LiveAccount.kind(of: row?[key]))
            }
            if row?["questions_permission"] is NSNumber {
                #expect(user.questionsPermission != nil, "the server sent a permission the model dropped")
            }
        }

        let teams = try await client.teamsPage()
        if teams.items.first != nil {
            let row = try await LiveAccount.firstRow(path: "\(apiV3)/teams")
            for key in ["recruiter_cap", "developer_cap", "invite_as"] {
                LiveAccount.report("Team.\(key)", expected: "present", actual: LiveAccount.kind(of: row?[key]))
            }
            #expect(row?["interviewer_count"] == nil, "`interviewer_count` exists after all — it was removed in 0.8.0")
        }
    }

    @Test
    func `an invite template's message decodes from content`() async throws {
        let page = try await client.inviteTemplatesPage()
        guard let template = page.items.first else {
            print("[live] SKIP  no invite templates on this account")
            return
        }

        let row = try await LiveAccount.firstRow(path: "\(apiV3)/templates")
        LiveAccount.report("InviteTemplate.content", expected: "string", actual: LiveAccount.kind(of: row?["content"]))
        #expect(row?["body"] == nil, "`body` exists after all — 0.8.0 moved to `content`")
        if row?["content"] is String {
            #expect(template.content != nil, "the server sent `content` but the model dropped it")
        }
    }

    @Test
    func `the organisation-wide candidate search returns people, not per-test records`() async throws {
        // Decoding these as `TestCandidate` needed an `id` the rows do not have, so before
        // 0.8.0 the lenient page decoder discarded every match and the search read empty.
        let envelope = try await LiveAccount.rawJSON(
            path: "\(apiV3)/candidates/search",
            query: [URLQueryItem(name: "query", value: "a"), URLQueryItem(name: "limit", value: "1")]
        )
        guard let row = (envelope["data"] as? [[String: Any]])?.first else {
            print("[live] SKIP  no candidate matched the probe query")
            return
        }

        LiveAccount.report("CandidateSearchResult.uuid", expected: "string", actual: LiveAccount.kind(of: row["uuid"]))
        LiveAccount.report(
            "CandidateSearchResult.attempts", expected: "array of object", actual: LiveAccount.kind(of: row["attempts"])
        )
        #expect(row["id"] == nil, "these rows carry an `id` after all")
    }

    @Test
    func `an interview's owner is the documented numeric id`() async throws {
        let page = try await client.interviewsPage()
        guard let interview = page.items.first else {
            print("[live] SKIP  no interviews on this account")
            return
        }

        let raw = try await LiveAccount.rawJSON(path: "\(apiV3)/interviews/\(interview.id)")
        LiveAccount.report("InterviewShow.user", expected: "number", actual: LiveAccount.kind(of: raw["user"]))

        let detail = try await client.interview(id: interview.id)
        if raw["user"] is NSNumber {
            #expect(detail.userID != nil, "the server sent a numeric owner the model dropped")
        } else if raw["user"] is [String: Any] {
            #expect(detail.user != nil, "the server expanded `user` and the model dropped it")
        }
    }

    @Test
    func `transcript timestamps are epoch milliseconds`() async throws {
        let page = try await client.interviewsPage()
        for interview in page.items.prefix(5) {
            let transcript = try await client.interviewTranscript(id: interview.id)
            guard let timestamp = transcript.messages.compactMap(\.timestamp).first else { continue }

            // 13 digits is milliseconds; 10 would be seconds, which is what the package
            // documented before 0.8.0 and which puts `sentAt` tens of millennia out.
            print("[live] INFO  transcript timestamp \(timestamp) has \(String(timestamp).count) digits")
            #expect(String(timestamp).count == 13, "timestamps are not milliseconds after all")
            return
        }
        print("[live] SKIP  no interview on this account has a transcript")
    }

    // MARK: Helpers

    /// The first candidate the account has, with the test it belongs to.
    private func firstCandidate() async throws -> (testID: String, candidateID: String)? {
        let tests = try await client.testsPage()
        for test in tests.items.prefix(10) {
            let candidates = try await client.candidatesPage(testID: test.id)
            if let candidate = candidates.items.first { return (test.id, candidate.id) }
        }
        return nil
    }
}
