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
//  They are skipped entirely without one, so CI is unaffected. **Read-only by default**:
//  GET checks never mutate. Opt-in write probes (SCIM create/delete, code-stub generate,
//  disposable interview update) run only when `HACKERRANK_ALLOW_WRITES=1` is also set.
//  The token is read from the environment and never written anywhere.
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

    /// Whether mutating probes may run. Off by default so a casual live pass stays read-only.
    nonisolated static var writesAllowed: Bool {
        ProcessInfo.processInfo.environment["HACKERRANK_ALLOW_WRITES"] == "1"
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

    // MARK: Assessment windows and sections

    @Test
    func `an assessment's window decodes from the keys the server sends`() async throws {
        let page = try await client.testsPage()
        guard let test = page.items.first else {
            print("[live] SKIP  no tests on this account")
            return
        }

        let row = try await LiveAccount.firstRow(path: "\(apiV3)/tests")
        // Live traffic uses `start_time`/`end_time`. The schema's `starttime`/`endtime` are
        // accepted as a fallback and are what writes still send.
        LiveAccount.report("Test.start_time", expected: "string", actual: LiveAccount.kind(of: row?["start_time"]))
        LiveAccount.report("Test.end_time", expected: "string", actual: LiveAccount.kind(of: row?["end_time"]))
        LiveAccount.report("Test.starttime", expected: "null/absent", actual: LiveAccount.kind(of: row?["starttime"]))

        if row?["start_time"] is String || row?["starttime"] is String {
            #expect(test.startTime != nil, "the server sent a window start but the model dropped it")
        }
        #expect(
            row?["start_time"] is String
                || row?["start_time"] is NSNull
                || row?["starttime"] is String
                || row?.keys.contains("start_time") == true
                || row?.keys.contains("starttime") == true,
            "neither window key is present — the model has nothing to read"
        )
    }

    @Test
    func `a test's sections arrive in the shape the model accepts`() async throws {
        let rows = await (try LiveAccount.rawJSON(path: "\(apiV3)/tests")["data"] as? [[String: Any]]) ?? []
        guard let sections = rows.compactMap({ $0["sections"] }).first(where: { !($0 is NSNull) }) else {
            print("[live] SKIP  no test on this account has sections")
            return
        }

        // Live accounts send an array of section objects; the schema documents an object.
        LiveAccount.report("Test.sections", expected: "array of object", actual: LiveAccount.kind(of: sections))
        #expect(sections is [String: Any] || sections is [Any], "sections is a shape the model cannot read")
    }

    // MARK: Candidate fields

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

        LiveAccount.report(
            "TestCandidate.attempt_events",
            expected: "array of object",
            actual: LiveAccount.kind(of: raw["attempt_events"])
        )
        LiveAccount.report(
            "TestCandidate.questions", expected: "object", actual: LiveAccount.kind(of: raw["questions"])
        )

        let light = try await LiveAccount.rawJSON(path: path)
        let heavyBytes = (try JSONSerialization.data(withJSONObject: raw)).count
        let lightBytes = (try JSONSerialization.data(withJSONObject: light)).count
        print("[live] INFO  candidate detail bytes with defaults \(heavyBytes), without \(lightBytes)")

        let candidate = try await client.candidate(testID: context.testID, candidateID: context.candidateID)
        if raw["questions"] is [String: Any] {
            #expect(candidate.questionScores?.isEmpty == false, "the server sent `questions` but the model kept none")
        }
        if let events = raw["attempt_events"] as? [Any], !events.isEmpty {
            #expect(candidate.attemptEvents?.isEmpty == false, "the server sent events but the model kept none")
        }
    }

    // MARK: Fields the models gained in 0.8.0

    @Test
    func `the documented fields the models gained are actually populated`() async throws {
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
        if let team = teams.items.first {
            let row = try await LiveAccount.firstRow(path: "\(apiV3)/teams")
            for key in ["recruiter_cap", "developer_cap", "invite_as", "interviewer_count"] {
                LiveAccount.report("Team.\(key)", expected: "present", actual: LiveAccount.kind(of: row?[key]))
            }
            if row?["interviewer_count"] is NSNumber {
                #expect(team.interviewerCount != nil, "the server sent interviewer_count but the model dropped it")
            }
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
        #expect(row?["body"] == nil || row?["body"] is NSNull, "`body` exists after all — 0.8.0 moved to `content`")
        if row?["content"] is String {
            #expect(template.content != nil, "the server sent `content` but the model dropped it")
        }
    }

    @Test
    func `the organisation-wide candidate search returns people, not per-test records`() async throws {
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
        #expect(row["id"] == nil || row["id"] is NSNull, "these rows carry an `id` after all")
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
            do {
                let transcript = try await client.interviewTranscript(id: interview.id)
                guard let timestamp = transcript.messages.compactMap(\.timestamp).first else { continue }

                print("[live] INFO  transcript timestamp \(timestamp) has \(String(timestamp).count) digits")
                #expect(String(timestamp).count == 13, "timestamps are not milliseconds after all")
                return
            } catch let HackerRankError.http(status, body) where status == 400 {
                print("[live] SKIP  transcript unavailable for \(interview.id): \(body)")
            }
        }
        print("[live] SKIP  no interview on this account has a usable transcript")
    }

    // MARK: Write probes (opt-in)

    @Test(.enabled(if: LiveAccount.writesAllowed))
    func `code stub generation accepts comma-joined API language ids`() async throws {
        let page = try await client.questionsPage()
        guard let question = page.items.first(where: { $0.type == "code" }) else {
            print("[live] SKIP  no owned code question")
            return
        }

        // Probe acceptance with a raw PUT so a nested envelope cannot fail the decode path
        // and hide a 400 from a bad language list.
        let body = GenerateCodeStubsRequest(options: CodeStubGenerationOptions(
            type: "code",
            functionName: "add",
            functionParams: "INTEGER a INTEGER b",
            functionReturn: "INTEGER",
            allowedLanguages: ["c", "clojure"]
        ))
        var request = URLRequest(
            url: try client.url(path: "\(apiV3)/questions/\(HackerRankClient.pathSegment(question.id))/generate")
        )
        request.httpMethod = "PUT"
        request.setValue("Bearer \(LiveAccount.token ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try HackerRankClient.makeEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        #expect(
            (200 ..< 300).contains(status),
            "generate rejected language list: \(String(data: data, encoding: .utf8) ?? "")"
        )
        print("[live] OK     CodeStubGenerationOptions.allowedLanguages as c,clojure")
    }

    @Test(.enabled(if: LiveAccount.writesAllowed))
    func `interview update replaces interviewers only when replace_interviewers is true`() async throws {
        let created = try await client.createQuickPad(
            title: "HRKit live replace probe \(Int(Date().timeIntervalSince1970))"
        )
        let id = try #require(created.id)
        do {
            // Omitting the flag (schema default false) must not replace an existing list. Seed one.
            _ = try await client.updateInterview(
                id: id,
                options: InterviewUpdateOptions(
                    interviewers: ["hello@adamdangoor.com"],
                    replaceInterviewers: true
                )
            )
            let seeded = try await client.interview(id: id)
            #expect(!seeded.interviewers.isEmpty)

            _ = try await client.updateInterview(
                id: id,
                options: InterviewUpdateOptions(
                    interviewers: ["accounts+codepair@dangoormendel.com"],
                    replaceInterviewers: false
                )
            )
            let afterFalse = try await client.interview(id: id)
            let emailsAfterFalse = Set(afterFalse.interviewers.compactMap(\.email))
            #expect(
                emailsAfterFalse.contains("hello@adamdangoor.com"),
                "replace_interviewers=false dropped the existing interviewer"
            )

            _ = try await client.updateInterview(
                id: id,
                options: InterviewUpdateOptions(
                    interviewers: ["hello@adamdangoor.com"],
                    replaceInterviewers: true
                )
            )
            let afterTrue = try await client.interview(id: id)
            let emailsAfterTrue = afterTrue.interviewers.compactMap(\.email)
            #expect(emailsAfterTrue == ["hello@adamdangoor.com"])
            print("[live] OK     InterviewUpdateOptions.replaceInterviewers default-true is required")
        } catch {
            _ = try? await client.deleteInterview(id: id)
            throw error
        }
        // Live DELETE answers 204 with an empty body; the typed decode may still throw.
        _ = try? await client.deleteInterview(id: id)
    }

    @Test(.enabled(if: LiveAccount.writesAllowed))
    func `SCIM user create accepts object emails on the services host`() async throws {
        let stamp = Int(Date().timeIntervalSince1970)
        let email = "hrkit.live.\(stamp)@example.invalid"
        let created = try await client.createSCIMUser(body: SCIMUserWriteRequest(
            userName: email,
            name: ["givenName": .string("HRKit"), "familyName": .string("Probe")],
            email: email,
            active: false
        ))
        #expect(created.id != nil)
        if let id = created.id {
            try await client.lockSCIMUser(id: id)
        }
        print("[live] OK     SCIMUserWriteRequest.emails as objects on \(HackerRankClient.defaultSCIMBaseURL)")
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
