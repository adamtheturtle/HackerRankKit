//
//  HackerRankClient.swift
//  HackerRankKit
//
//  The networking client and the paginated/decode-only response envelopes it
//  consumes. The low-level request, pagination, and decoding plumbing lives in the
//  `PaginatedRESTClient` dependency.
//

import Foundation
import os.log
import PaginatedRESTClient

// MARK: - Error mapping

/// Maps the generic transport's failures onto ``HackerRankError`` and decides which
/// mapped errors are transient. Injecting this keeps `PaginatedRESTClient` free of any
/// HackerRank-specific error while the transport still throws exactly the
/// ``HackerRankError`` values callers catch, so `isUnauthorized` detection is unchanged.
private struct HackerRankErrorMapping: RESTTransportErrorMapping {
    nonisolated func missingAPIKey() -> any Error {
        HackerRankError.missingAPIKey
    }

    nonisolated func http(status: Int, body: String) -> any Error {
        HackerRankError.http(status, body)
    }

    nonisolated func decode(_ detail: String) -> any Error {
        HackerRankError.decode(detail)
    }

    nonisolated func network(_ error: URLError) -> any Error {
        HackerRankError.network(error)
    }

    /// Retry idempotent GETs on the transient failures the server asks us to back off
    /// from (429, 5xx) and the recoverable transport errors, before surfacing them.
    /// Everything else — 4xx auth/validation, decoding — is permanent.
    nonisolated func isTransient(_ error: any Error) -> Bool {
        if let api = error as? HackerRankError {
            if case let .http(code, _) = api {
                return (500 ... 599).contains(code) || code == 429 || code == 408
            }
            if case let .network(urlError) = api {
                return [.timedOut, .networkConnectionLost, .cannotConnectToHost,
                        .notConnectedToInternet, .dnsLookupFailed].contains(urlError.code)
            }
            return false
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return [NSURLErrorTimedOut,
                    NSURLErrorNetworkConnectionLost,
                    NSURLErrorCannotConnectToHost].contains(nsError.code)
        }
        return false
    }
}

// MARK: - Client

/// A client for the HackerRank for Work v3 API.
///
/// Construct one with a personal access token (and, for regional deployments, a custom
/// base URL), then call the typed endpoint methods. Each method is a thin wrapper over a
/// generic `PaginatedRESTClient` transport that handles request building, retries on
/// idempotent GETs, off-main JSON decoding, and pagination, so list methods follow the
/// `next` cursor rather than just the first page.
///
/// The client carries only immutable, `Sendable` configuration, so it is safe to share
/// and to use from any actor.
public struct HackerRankClient {
    // The client carries only immutable, Sendable configuration and drives pure
    // networking, so these are `nonisolated`: it lets the low-level request/pagination
    // methods run off the main actor rather than being pinned to it by the module's
    // default MainActor isolation.
    public nonisolated let token: String
    public nonisolated let baseURL: URL
    public nonisolated let session: URLSession

    /// The generic transport that does the request building, retries, pagination, and
    /// background decoding. The endpoint methods below are thin wrappers over it; the
    /// error mapping and JSON coders are injected, so the transport stays domain-free.
    nonisolated let rest: PaginatedRESTClient

    /// Items requested per page — the API's maximum (requests above 100 are rejected).
    /// Real accounts have huge collections (≈9.7k questions, ≈87k interviews), so the
    /// list methods page through them via the `next` cursor rather than draining every
    /// page up front.
    nonisolated static let pageSize = 100
    nonisolated static let apiV3 = "/x/api/v3"

    /// The standard hosted HackerRank endpoint, used when an account doesn't override it
    /// (e.g. a regional deployment).
    public static let defaultBaseURL = URL(string: "https://www.hackerrank.com") ?? URL(fileURLWithPath: "/")

    /// - Parameters:
    ///   - token: the HackerRank personal access token, sent as the Bearer credential.
    ///   - baseURL: the account's base URL; defaults to ``defaultBaseURL``.
    ///   - session: the URL session backing the transport; defaults to ``liveSession``.
    public init(token: String,
                baseURL: URL = Self.defaultBaseURL,
                session: URLSession = Self.liveSession) {
        self.token = token
        self.baseURL = baseURL
        self.session = session
        rest = PaginatedRESTClient(
            apiKey: token,
            baseURL: baseURL,
            transport: URLSessionTransport(session: session),
            decoderFactory: Self.makeDecoder,
            encoderFactory: Self.makeEncoder,
            errors: HackerRankErrorMapping(),
            log: { apiLogger.debug("\($0, privacy: .public)") }
        )
    }

    /// The single construction point for the live network session, so request policy
    /// (timeouts, caching) lives here rather than relying on the process-wide
    /// `URLSession.shared` singleton.
    public static let liveSession: URLSession = makeLiveSession()

    private static func makeLiveSession() -> URLSession {
        let config = URLSessionConfiguration.default
        // The retry layer handles transient timeouts, so keep the standard 60s
        // per-request timeout rather than failing fast.
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config)
    }

    /// A live client against the hosted (or a custom) HackerRank endpoint.
    public static func live(token: String, baseURL: URL = Self.defaultBaseURL) -> Self {
        Self(token: token, baseURL: baseURL, session: liveSession)
    }

    /// Builds a configured decoder. A factory rather than a shared instance because
    /// decoding runs off the main actor, and `JSONDecoder` isn't safe to share across
    /// threads: each background decode gets its own.
    public nonisolated static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    /// Shared decoder for callers that decode on the current actor (e.g. tests). The
    /// network path decodes off-main via ``makeDecoder()`` instead.
    public static let decoder: JSONDecoder = makeDecoder()

    /// Builds the request-body encoder. `nonisolated` (like ``makeDecoder()``) so the
    /// transport's `@Sendable` `encoderFactory` can call it off the main actor.
    public nonisolated static func makeEncoder() -> JSONEncoder {
        JSONEncoder()
    }

    /// Shared encoder for callers that encode on the current actor (e.g. tests).
    public static let encoder: JSONEncoder = makeEncoder()

    // MARK: Tests

    /// One page of the account's tests, plus the cursor for the next page.
    public func testsPage(after cursor: String? = nil) async throws -> Page<Test> {
        try await page(HackerRankPage<Test>.self, path: "\(Self.apiV3)/tests", cursor: cursor)
    }

    /// One page of a test's candidates, plus the cursor for the next page.
    public func candidatesPage(testID: String, after cursor: String? = nil) async throws -> Page<TestCandidate> {
        try await page(
            HackerRankPage<TestCandidate>.self,
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates",
            cursor: cursor
        )
    }

    /// Invites a candidate to a test (`POST /tests/{id}/candidates`). A UI should confirm
    /// the invite before it runs.
    ///
    /// - Returns: the created candidate as echoed by the API (fields are optional, so a
    ///   2xx never fails on an unexpected response shape).
    @discardableResult
    public func inviteCandidate(
        testID: String,
        email: String,
        fullName: String? = nil,
        sendEmail: Bool = true
    ) async throws -> InvitedCandidate {
        let trimmedName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = InviteCandidateRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            fullName: (trimmedName?.isEmpty == false) ? trimmedName : nil,
            sendEmail: sendEmail
        )
        return try await rest.send(
            InvitedCandidate.self,
            method: "POST",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates",
            body: body
        )
    }

    /// Creates a test (`POST /tests`).
    @discardableResult
    public func createTest(name: String) async throws -> CreatedTest {
        let body = CreateTestRequest(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        return try await rest.send(CreatedTest.self, method: "POST", path: "\(Self.apiV3)/tests", body: body)
    }

    /// Renames a test (`PATCH /tests/{id}`).
    @discardableResult
    public func updateTest(testID: String, name: String) async throws -> CreatedTest {
        let body = UpdateTestRequest(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        return try await rest.send(
            CreatedTest.self,
            method: "PATCH",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))",
            body: body
        )
    }

    /// Permanently deletes a test (`DELETE /tests/{id}`). Destructive and irreversible,
    /// so a UI should confirm before this is called.
    @discardableResult
    public func deleteTest(testID: String) async throws -> CreatedTest {
        try await rest.send(
            CreatedTest.self,
            method: "DELETE",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))",
            body: EmptyBody()
        )
    }

    /// The richer single-test read (`GET /tests/{id}`) backing a detail view. Adds the
    /// candidate login links, the master password, and the MCQ scoring over the list row.
    public func test(id: String) async throws -> TestDetail {
        try await rest.fetch(TestDetail.self, path: "\(Self.apiV3)/tests/\(Self.pathSegment(id))")
    }

    // MARK: Questions

    /// One page of the account's questions, plus the cursor for the next page.
    public func questionsPage(after cursor: String? = nil) async throws -> Page<Question> {
        try await page(HackerRankPage<Question>.self, path: "\(Self.apiV3)/questions", cursor: cursor)
    }

    /// The richer single-question read (`GET /questions/{id}`) backing a detail view.
    /// Adds the MCQ options/answer and internal notes over the list row.
    public func question(id: String) async throws -> QuestionDetail {
        try await rest.fetch(QuestionDetail.self, path: "\(Self.apiV3)/questions/\(Self.pathSegment(id))")
    }

    // MARK: Interviews

    /// One page of the account's interviews, plus the cursor for the next page.
    ///
    /// Requests **newest-first** ordering from the server (`order_by=created_at&order_dir=desc`).
    /// Real accounts have huge interview collections (≈87k) returned oldest-first by
    /// default, so without this the first pages a user scrolls are the oldest interviews.
    /// `createdAtRange` (a `created_at=<from>..<to>` value) filters by creation date
    /// server-side when set; it's ignored on follow-up pages (the absolute `next` cursor
    /// already carries every query parameter).
    public func interviewsPage(after cursor: String? = nil, createdAtRange: String? = nil) async throws
        -> Page<Interview> {
        var query = [
            URLQueryItem(name: "order_by", value: "created_at"),
            URLQueryItem(name: "order_dir", value: "desc")
        ]
        if let createdAtRange {
            query.append(URLQueryItem(name: "created_at", value: createdAtRange))
        }
        return try await page(
            HackerRankPage<Interview>.self,
            path: "\(Self.apiV3)/interviews",
            cursor: cursor,
            query: query
        )
    }

    /// Creates an instant QuickPad collaborative interview (`POST /interviews`).
    @discardableResult
    public func createQuickPad(title: String? = nil) async throws -> CreatedInterview {
        // The API rejects a titleless interview with HTTP 400, so fall back to a dated
        // default rather than surfacing an error for an optional title.
        let body = CreateQuickPadRequest(title: Self.nonBlank(title) ?? Self.defaultQuickPadTitle(), quickpad: true)
        return try await rest.send(CreatedInterview.self, method: "POST", path: "\(Self.apiV3)/interviews", body: body)
    }

    /// Schedules an interview (`POST /interviews`). The start time is sent as an
    /// ISO-8601 timestamp.
    @discardableResult
    public func scheduleInterview(
        title: String,
        from: Date,
        candidateEmail: String? = nil,
        notes: String? = nil
    ) async throws -> CreatedInterview {
        let body = ScheduleInterviewRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            from: ISO8601DateFormatter().string(from: from),
            candidate: Self.nonBlank(candidateEmail),
            notes: Self.nonBlank(notes)
        )
        return try await rest.send(CreatedInterview.self, method: "POST", path: "\(Self.apiV3)/interviews", body: body)
    }

    /// The richer single-interview read (`GET /interviews/{id}`) backing a detail view.
    /// Adds the scheduled window, interviewers, owner, candidate, and result/résumé links.
    public func interview(id: String) async throws -> InterviewDetail {
        try await rest.fetch(InterviewDetail.self, path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))")
    }

    /// The interview's conversation transcript (`GET /interviews/{id}/transcript`) — the
    /// spoken/typed messages only; the collaborative pad's source code is not exposed.
    public func interviewTranscript(id: String) async throws -> InterviewTranscript {
        try await rest.fetch(
            InterviewTranscript.self,
            path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))/transcript"
        )
    }

    // MARK: Users

    /// One page of the organisation's users (members), plus the cursor for the next page.
    public func usersPage(after cursor: String? = nil) async throws -> Page<User> {
        try await page(HackerRankPage<User>.self, path: "\(Self.apiV3)/users", cursor: cursor)
    }

    /// Creates an organisation user (`POST /users`).
    @discardableResult
    public func createUser(
        email: String,
        firstName: String? = nil,
        lastName: String? = nil,
        role: String? = nil
    ) async throws -> CreatedUser {
        let body = CreateUserRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            firstName: Self.nonBlank(firstName),
            lastName: Self.nonBlank(lastName),
            role: Self.nonBlank(role)
        )
        return try await rest.send(CreatedUser.self, method: "POST", path: "\(Self.apiV3)/users", body: body)
    }

    /// The user the token belongs to (`GET /users/me`). Used to auto-discover an
    /// account's identity. Returns a single user object (not a paged envelope).
    public func currentUser() async throws -> User {
        try await rest.fetch(User.self, path: "\(Self.apiV3)/users/me")
    }

    // MARK: Teams

    /// One page of the organisation's teams, plus the cursor for the next page.
    public func teamsPage(after cursor: String? = nil) async throws -> Page<Team> {
        try await page(HackerRankPage<Team>.self, path: "\(Self.apiV3)/teams", cursor: cursor)
    }

    /// One page of a team's members (users), plus the cursor for the next page.
    public func teamMembersPage(teamID: String, after cursor: String? = nil) async throws -> Page<User> {
        try await page(
            HackerRankPage<User>.self,
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(teamID))/users",
            cursor: cursor
        )
    }

    /// Creates a team (`POST /teams`).
    @discardableResult
    public func createTeam(name: String) async throws -> CreatedTeam {
        let body = CreateTeamRequest(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        return try await rest.send(CreatedTeam.self, method: "POST", path: "\(Self.apiV3)/teams", body: body)
    }

    /// Adds a member to a team (`POST /teams/{id}/users`).
    @discardableResult
    public func addTeamMember(teamID: String, email: String, role: String? = nil) async throws
        -> TeamMembershipResult {
        let body = AddTeamMemberRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            role: Self.nonBlank(role)
        )
        return try await rest.send(
            TeamMembershipResult.self,
            method: "POST",
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(teamID))/users",
            body: body
        )
    }

    /// Removes a member from a team (`DELETE /teams/{id}/users/{userID}`). Destructive,
    /// so a UI should confirm before this is called.
    @discardableResult
    public func removeTeamMember(teamID: String, userID: String) async throws -> TeamMembershipResult {
        try await rest.send(
            TeamMembershipResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(teamID))/users/\(Self.pathSegment(userID))",
            body: EmptyBody()
        )
    }

    // MARK: Token validation

    /// Lightweight token validation: requests a single test. A 2xx response (even with
    /// no tests) means the token authenticates; an auth failure throws
    /// ``HackerRankError/http(_:_:)`` with a 401/403 status. Throws before any request
    /// when the token is empty.
    public func validateToken() async throws {
        guard !token.isEmpty else { throw HackerRankError.missingAPIKey }

        var components = URLComponents(
            url: baseURL.appending(path: "\(Self.apiV3)/tests"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "limit", value: "1")]
        guard let url = components?.url else {
            throw HackerRankError.http(0, "Could not build the validation URL.")
        }

        _ = try await rest.performWithRetry(HackerRankPage<Test>.self, request: rest.authorizedGET(url))
    }

    // MARK: - Paging helpers

    /// Fetches a single page: the first page (with an explicit page size) when `cursor`
    /// is `nil`, or the page at the given absolute `next` cursor URL otherwise.
    nonisolated func page<Item: Decodable & Sendable>(
        _: HackerRankPage<Item>.Type,
        path: String,
        cursor: String?,
        query: [URLQueryItem] = []
    ) async throws -> Page<Item> {
        let url = try pageURL(path: path, cursor: cursor, query: query)
        let response = try await rest.performWithRetry(HackerRankPage<Item>.self, request: rest.authorizedGET(url))
        return Page(items: response.data, next: response.next, totalCount: response.totalCount)
    }

    /// The absolute `cursor` URL when continuing, or the first-page URL (base + path +
    /// `limit`, plus any endpoint-specific `query`) when starting.
    nonisolated func pageURL(path: String, cursor: String?, query: [URLQueryItem] = []) throws -> URL {
        if let cursor {
            guard let url = URL(string: cursor) else {
                throw HackerRankError.http(0, "Invalid next-page URL.")
            }

            return url
        }

        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: String(Self.pageSize))] + query
        guard let url = components?.url else {
            throw HackerRankError.http(0, "Could not build the page URL.")
        }

        return url
    }

    /// Trims `value` and returns `nil` for an empty/whitespace-only result, so blank
    /// optional fields are omitted from a write body rather than sent empty.
    nonisolated static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (result?.isEmpty == false) ? result : nil
    }

    /// A dated fallback title for a QuickPad created without one, so the optional title
    /// stays optional while the API still receives the title it requires.
    nonisolated static func defaultQuickPadTitle() -> String {
        "QuickPad \(Date.now.formatted(date: .abbreviated, time: .shortened))"
    }

    /// Percent-encodes an id for use as a single path segment.
    nonisolated static func pathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// One page of a list endpoint: the decoded items plus the cursor (absolute `next` URL)
/// for the following page, or `nil` on the last page.
public nonisolated struct Page<Item: Sendable>: Sendable {
    public let items: [Item]
    public let next: String?
    /// The collection's exact total from the API envelope, when the endpoint provides one.
    public let totalCount: Int?

    public init(items: [Item], next: String?, totalCount: Int? = nil) {
        self.items = items
        self.next = next
        self.totalCount = totalCount
    }
}
