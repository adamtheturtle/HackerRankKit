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

    /// The richer single-candidate read (`GET /tests/{test_id}/candidates/{candidate_id}`),
    /// backing detail refreshes that need fields beyond the paged list row.
    public func candidate(testID: String, candidateID: String) async throws -> TestCandidate {
        try await rest.fetch(
            TestCandidate.self,
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))"
        )
    }

    /// Updates candidate metadata/invite settings (`PUT /tests/{test_id}/candidates/{candidate_id}`).
    @discardableResult
    public func updateCandidate(
        testID: String,
        candidateID: String,
        options: CandidateUpdateOptions = CandidateUpdateOptions()
    ) async throws -> TestCandidate {
        try await rest.send(
            TestCandidate.self,
            method: "PUT",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))",
            body: UpdateCandidateRequest(options: options)
        )
    }

    /// Cancels an outstanding candidate invite (`DELETE /tests/{test_id}/candidates/{candidate_id}/invite`).
    @discardableResult
    public func cancelCandidateInvite(testID: String, candidateID: String) async throws -> CandidateWriteResult {
        try await rest.send(
            CandidateWriteResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))/invite",
            body: EmptyBody()
        )
    }

    /// Fetches the URL for a candidate's report PDF (`GET /tests/{test_id}/candidates/{candidate_id}/pdf?format=url`).
    public func candidateReportPDF(testID: String, candidateID: String) async throws -> CandidateReportPDF {
        var components = URLComponents(
            url: baseURL.appending(
                path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))/pdf"
            ),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "format", value: "url")]
        guard let url = components?.url else {
            throw HackerRankError.http(0, "Could not build the candidate report PDF URL.")
        }
        return try await rest.performWithRetry(CandidateReportPDF.self, request: rest.authorizedGET(url))
    }

    /// Deletes a candidate report (`DELETE /tests/{test_id}/candidates/{candidate_id}/report`).
    @discardableResult
    public func deleteCandidateReport(testID: String, candidateID: String) async throws -> CandidateWriteResult {
        try await rest.send(
            CandidateWriteResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))/report",
            body: EmptyBody()
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
        sendEmail: Bool = true,
        options: CandidateInviteOptions = CandidateInviteOptions()
    ) async throws -> InvitedCandidate {
        let trimmedName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = InviteCandidateRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            fullName: (trimmedName?.isEmpty == false) ? trimmedName : nil,
            sendEmail: sendEmail,
            options: options
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
    public func createTest(name: String, options: TestWriteOptions = TestWriteOptions()) async throws -> CreatedTest {
        let body = CreateTestRequest(name: name.trimmingCharacters(in: .whitespacesAndNewlines), options: options)
        return try await rest.send(CreatedTest.self, method: "POST", path: "\(Self.apiV3)/tests", body: body)
    }

    /// Archives a test (`POST /tests/{id}/archive`).
    @discardableResult
    public func archiveTest(testID: String) async throws -> CreatedTest {
        try await rest.send(
            CreatedTest.self,
            method: "POST",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/archive",
            body: EmptyBody()
        )
    }

    /// Renames a test (`PUT /tests/{id}`).
    @discardableResult
    public func updateTest(
        testID: String,
        name: String,
        options: TestWriteOptions = TestWriteOptions()
    ) async throws -> CreatedTest {
        let body = UpdateTestRequest(name: name.trimmingCharacters(in: .whitespacesAndNewlines), options: options)
        return try await rest.send(
            CreatedTest.self,
            method: "PUT",
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

    /// One page of users who can invite candidates to a test
    /// (`GET /tests/{id}/inviters`), plus the cursor for the next page.
    public func testInviters(testID: String, after cursor: String? = nil) async throws -> Page<TestInviter> {
        try await page(
            HackerRankPage<TestInviter>.self,
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/inviters",
            cursor: cursor
        )
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

    /// Creates a question (`POST /questions`) using the stable shared metadata fields.
    /// Type-specific authoring payloads can be added in a later layer.
    @discardableResult
    public func createQuestion(
        name: String,
        type: String,
        options: QuestionWriteOptions = QuestionWriteOptions()
    ) async throws -> WrittenQuestion {
        let body = CreateQuestionRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type.trimmingCharacters(in: .whitespacesAndNewlines),
            options: options
        )
        return try await rest.send(WrittenQuestion.self, method: "POST", path: "\(Self.apiV3)/questions", body: body)
    }

    /// Updates question metadata (`PUT /questions/{id}`). Pass only the fields that should
    /// change; unset values are omitted.
    @discardableResult
    public func updateQuestion(
        questionID: String,
        name: String? = nil,
        type: String? = nil,
        options: QuestionWriteOptions = QuestionWriteOptions()
    ) async throws -> WrittenQuestion {
        let body = UpdateQuestionRequest(
            name: Self.nonBlank(name),
            type: Self.nonBlank(type),
            options: options
        )
        return try await rest.send(
            WrittenQuestion.self,
            method: "PUT",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))",
            body: body
        )
    }

    /// Deletes a question (`DELETE /questions/{id}`). Destructive and irreversible,
    /// so a UI should confirm before this is called.
    @discardableResult
    public func deleteQuestion(questionID: String) async throws -> WrittenQuestion {
        try await rest.send(
            WrittenQuestion.self,
            method: "DELETE",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))",
            body: EmptyBody()
        )
    }

    /// Updates a coding question's custom code stubs (`PUT /questions/{id}/custom_codestubs`).
    @discardableResult
    public func updateCustomCodeStubs(
        questionID: String,
        stubs: [QuestionCodeStub]
    ) async throws -> QuestionOperationResult {
        try await rest.send(
            QuestionOperationResult.self,
            method: "PUT",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/custom_codestubs",
            body: CustomCodeStubsRequest(stubs: stubs)
        )
    }

    /// Generates code stubs for a coding question (`PUT /questions/{id}/generate`).
    @discardableResult
    public func generateCodeStubs(
        questionID: String,
        options: CodeStubGenerationOptions = CodeStubGenerationOptions()
    ) async throws -> QuestionOperationResult {
        try await rest.send(
            QuestionOperationResult.self,
            method: "PUT",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/generate",
            body: GenerateCodeStubsRequest(options: options)
        )
    }

    /// Adds a testcase to a question (`POST /questions/{id}/testcases`).
    @discardableResult
    public func addTestcase(
        questionID: String,
        options: QuestionTestcaseOptions
    ) async throws -> QuestionOperationResult {
        try await rest.send(
            QuestionOperationResult.self,
            method: "POST",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/testcases",
            body: QuestionTestcaseRequest(options: options)
        )
    }

    /// Updates a testcase (`PUT /questions/{id}/testcases/{testcase_id}`).
    @discardableResult
    public func updateTestcase(
        questionID: String,
        testcaseID: String,
        options: QuestionTestcaseOptions
    ) async throws -> QuestionOperationResult {
        try await rest.send(
            QuestionOperationResult.self,
            method: "PUT",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/testcases/\(Self.pathSegment(testcaseID))",
            body: QuestionTestcaseRequest(options: options)
        )
    }

    /// Deletes a testcase (`DELETE /questions/{id}/testcases/{testcase_id}`).
    @discardableResult
    public func deleteTestcase(questionID: String, testcaseID: String) async throws -> QuestionOperationResult {
        try await rest.send(
            QuestionOperationResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/testcases/\(Self.pathSegment(testcaseID))",
            body: EmptyBody()
        )
    }

    /// Deletes all testcases for a question (`DELETE /questions/{id}/testcases/delete_all`).
    @discardableResult
    public func deleteAllTestcases(questionID: String) async throws -> QuestionOperationResult {
        try await rest.send(
            QuestionOperationResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/testcases/delete_all",
            body: EmptyBody()
        )
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

    /// Creates an instant Pad collaborative interview.
    ///
    /// Alias for `createQuickPad(title:)` retained for app call sites that use the product-facing
    /// "Pad" naming.
    @discardableResult
    public func createPad(title: String? = nil) async throws -> CreatedInterview {
        try await createQuickPad(title: title)
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

    /// Updates an interview (`PUT /interviews/{id}`).
    @discardableResult
    public func updateInterview(
        id: String,
        options: InterviewUpdateOptions = InterviewUpdateOptions()
    ) async throws -> CreatedInterview {
        try await rest.send(
            CreatedInterview.self,
            method: "PUT",
            path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))",
            body: UpdateInterviewRequest(options: options)
        )
    }

    /// Deletes an interview (`DELETE /interviews/{id}`). Destructive, so a UI should confirm before this is called.
    @discardableResult
    public func deleteInterview(id: String) async throws -> CreatedInterview {
        try await rest.send(
            CreatedInterview.self,
            method: "DELETE",
            path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))",
            body: EmptyBody()
        )
    }

    /// The interview's conversation transcript (`GET /interviews/{id}/transcript`) — the
    /// spoken/typed messages only; the collaborative pad's source code is not exposed.
    public func interviewTranscript(id: String) async throws -> InterviewTranscript {
        try await rest.fetch(
            InterviewTranscript.self,
            path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))/transcript"
        )
    }

    // MARK: Interview templates

    /// One page of interview templates (`GET /interview_templates`).
    public func interviewTemplatesPage(after cursor: String? = nil) async throws -> Page<InterviewTemplate> {
        try await page(
            HackerRankPage<InterviewTemplate>.self, path: "\(Self.apiV3)/interview_templates", cursor: cursor
        )
    }

    /// Shows an interview template (`GET /interview_templates/{template_id}`).
    public func interviewTemplate(id: Int) async throws -> InterviewTemplate {
        try await rest.fetch(InterviewTemplate.self, path: "\(Self.apiV3)/interview_templates/\(id)")
    }

    /// Creates an interview template (`POST /interview_templates`).
    @discardableResult
    public func createInterviewTemplate(
        options: InterviewTemplateWriteOptions
    ) async throws -> InterviewTemplate {
        try await rest.send(
            InterviewTemplate.self,
            method: "POST",
            path: "\(Self.apiV3)/interview_templates",
            body: InterviewTemplateWriteRequest(options: options)
        )
    }

    /// Updates an interview template (`PUT /interview_templates/{template_id}`).
    @discardableResult
    public func updateInterviewTemplate(
        id: Int,
        options: InterviewTemplateWriteOptions = InterviewTemplateWriteOptions()
    ) async throws -> InterviewTemplate {
        try await rest.send(
            InterviewTemplate.self,
            method: "PUT",
            path: "\(Self.apiV3)/interview_templates/\(id)",
            body: InterviewTemplateWriteRequest(options: options)
        )
    }

    /// Deletes an interview template (`DELETE /interview_templates/{template_id}`).
    @discardableResult
    public func deleteInterviewTemplate(id: Int) async throws -> InterviewTemplateWriteResult {
        try await rest.send(
            InterviewTemplateWriteResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/interview_templates/\(id)",
            body: EmptyBody()
        )
    }

    // MARK: Invite templates

    /// One page of invite templates (`GET /templates`), optionally filtered by access.
    public func inviteTemplatesPage(
        after cursor: String? = nil, access: String? = nil
    ) async throws -> Page<InviteTemplate> {
        try await page(
            HackerRankPage<InviteTemplate>.self,
            path: "\(Self.apiV3)/templates",
            cursor: cursor,
            query: Self.nonBlank(access).map { [URLQueryItem(name: "access", value: $0)] } ?? []
        )
    }

    /// Shows an invite template (`GET /templates/{template_id}`).
    public func inviteTemplate(id: String) async throws -> InviteTemplate {
        try await rest.fetch(InviteTemplate.self, path: "\(Self.apiV3)/templates/\(Self.pathSegment(id))")
    }

    // MARK: ATS

    /// Creates an ATS-backed interview invite (`POST /ats/codepair`).
    @discardableResult
    public func createATSCodePairInvite(
        title: String,
        requisitionID: String,
        candidateID: String,
        options: ATSCodePairOptions = ATSCodePairOptions()
    ) async throws -> ATSInviteResult {
        let body = ATSCodePairRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            requisitionID: requisitionID.trimmingCharacters(in: .whitespacesAndNewlines),
            candidateID: candidateID.trimmingCharacters(in: .whitespacesAndNewlines),
            options: options
        )
        return try await rest.send(ATSInviteResult.self, method: "POST", path: "\(Self.apiV3)/ats/codepair", body: body)
    }

    /// Creates an ATS-backed test candidate invite (`POST /ats/codescreen`).
    @discardableResult
    public func createATSCodeScreenInvite(
        testID: String,
        requisitionID: String,
        candidateID: String,
        email: String,
        options: ATSCodeScreenOptions = ATSCodeScreenOptions()
    ) async throws -> ATSInviteResult {
        let body = ATSCodeScreenRequest(
            testID: testID.trimmingCharacters(in: .whitespacesAndNewlines),
            requisitionID: requisitionID.trimmingCharacters(in: .whitespacesAndNewlines),
            candidateID: candidateID.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            options: options
        )
        return try await rest.send(
            ATSInviteResult.self, method: "POST", path: "\(Self.apiV3)/ats/codescreen", body: body
        )
    }

    // MARK: SCIM provisioning

    /// Lists users from the legacy SCIM provisioning endpoint (`GET /Users`).
    public func scimUsers(limit: Int = 100, offset: Int = 0) async throws -> SCIMListResponse<SCIMUser> {
        let url = try offsetURL(path: "/Users", limit: limit, offset: offset)
        return try await rest.performWithRetry(SCIMListResponse<SCIMUser>.self, request: rest.authorizedGET(url))
    }

    /// Retrieves a user from the legacy SCIM provisioning endpoint (`GET /Users/{id}`).
    public func scimUser(id: String) async throws -> SCIMUser {
        try await rest.fetch(SCIMUser.self, path: "/Users/\(Self.pathSegment(id))")
    }

    /// Creates a user through the legacy SCIM provisioning endpoint (`POST /Users`).
    @discardableResult
    public func createSCIMUser(body: SCIMUserWriteRequest) async throws -> SCIMUser {
        try await rest.send(SCIMUser.self, method: "POST", path: "/Users", body: body)
    }

    /// Replaces a user through the legacy SCIM provisioning endpoint (`PUT /Users/{id}`).
    @discardableResult
    public func updateSCIMUser(id: String, body: SCIMUserWriteRequest) async throws -> SCIMUser {
        try await rest.send(SCIMUser.self, method: "PUT", path: "/Users/\(Self.pathSegment(id))", body: body)
    }

    /// Patches a user through the legacy SCIM provisioning endpoint (`PATCH /Users/{id}`).
    @discardableResult
    public func patchSCIMUser(id: String, body: SCIMPatchRequest) async throws -> SCIMUser {
        try await rest.send(SCIMUser.self, method: "PATCH", path: "/Users/\(Self.pathSegment(id))", body: body)
    }

    /// Locks a user through the legacy SCIM provisioning endpoint (`DELETE /Users/{id}`).
    public func lockSCIMUser(id: String) async throws {
        try await sendNoContent(method: "DELETE", path: "/Users/\(Self.pathSegment(id))")
    }

    /// Lists groups from the legacy SCIM provisioning endpoint (`GET /Groups`).
    public func scimGroups(limit: Int = 100, offset: Int = 0) async throws -> SCIMListResponse<SCIMGroup> {
        let url = try offsetURL(path: "/Groups", limit: limit, offset: offset)
        return try await rest.performWithRetry(SCIMListResponse<SCIMGroup>.self, request: rest.authorizedGET(url))
    }

    /// Retrieves a group from the legacy SCIM provisioning endpoint (`GET /Groups/{id}`).
    public func scimGroup(id: String) async throws -> SCIMGroup {
        try await rest.fetch(SCIMGroup.self, path: "/Groups/\(Self.pathSegment(id))")
    }

    /// Creates a group through the legacy SCIM provisioning endpoint (`POST /Groups`).
    @discardableResult
    public func createSCIMGroup(body: SCIMGroupWriteRequest) async throws -> SCIMGroup {
        try await rest.send(SCIMGroup.self, method: "POST", path: "/Groups", body: body)
    }

    /// Patches a group through the legacy SCIM provisioning endpoint (`PATCH /Groups/{id}`).
    @discardableResult
    public func patchSCIMGroup(id: String, body: SCIMPatchRequest) async throws -> SCIMGroup {
        try await rest.send(SCIMGroup.self, method: "PATCH", path: "/Groups/\(Self.pathSegment(id))", body: body)
    }

    /// Deprovisions a group through the legacy SCIM provisioning endpoint (`DELETE /Groups/{id}`).
    public func deprovisionSCIMGroup(id: String) async throws {
        try await sendNoContent(method: "DELETE", path: "/Groups/\(Self.pathSegment(id))")
    }

    // MARK: Users

    /// One page of the organisation's users (members), plus the cursor for the next page.
    public func usersPage(after cursor: String? = nil) async throws -> Page<User> {
        try await page(HackerRankPage<User>.self, path: "\(Self.apiV3)/users", cursor: cursor)
    }

    /// Creates an organisation user (`POST /users`).
    ///
    /// The server requires `email`, `firstName`, `role`, and at least one team id — it
    /// rejects the request with HTTP 400 ("Parameter teams is required") otherwise. The
    /// parameters stay optional here so the server remains the source of truth for
    /// validation; an empty `teamIDs` is omitted from the body.
    @discardableResult
    public func createUser(
        email: String,
        firstName: String? = nil,
        lastName: String? = nil,
        role: String? = nil,
        teamIDs: [String] = []
    ) async throws -> CreatedUser {
        let body = CreateUserRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            firstName: Self.nonBlank(firstName),
            lastName: Self.nonBlank(lastName),
            role: Self.nonBlank(role),
            teams: teamIDs.isEmpty ? nil : teamIDs.map(CreateUserRequest.TeamRef.init)
        )
        return try await rest.send(CreatedUser.self, method: "POST", path: "\(Self.apiV3)/users", body: body)
    }

    /// Retrieves a user by id (`GET /users/{id}`).
    public func user(id: String) async throws -> User {
        try await rest.fetch(User.self, path: "\(Self.apiV3)/users/\(Self.pathSegment(id))")
    }

    /// Updates a user (`PUT /users/{id}`).
    @discardableResult
    public func updateUser(id: String, options: UserUpdateOptions = UserUpdateOptions()) async throws -> User {
        try await rest.send(
            User.self,
            method: "PUT",
            path: "\(Self.apiV3)/users/\(Self.pathSegment(id))",
            body: UpdateUserRequest(options: options)
        )
    }

    /// Locks a user (`DELETE /users/{id}`).
    @discardableResult
    public func lockUser(id: String) async throws -> UserWriteResult {
        try await rest.send(
            UserWriteResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/users/\(Self.pathSegment(id))",
            body: EmptyBody()
        )
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

    /// Retrieves a team by id (`GET /teams/{id}`).
    public func team(id: String) async throws -> Team {
        try await rest.fetch(Team.self, path: "\(Self.apiV3)/teams/\(Self.pathSegment(id))")
    }

    /// Updates a team (`PUT /teams/{id}`).
    @discardableResult
    public func updateTeam(id: String, options: TeamUpdateOptions = TeamUpdateOptions()) async throws -> Team {
        try await rest.send(
            Team.self,
            method: "PUT",
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(id))",
            body: UpdateTeamRequest(options: options)
        )
    }

    /// Deletes a team (`DELETE /teams/{id}`). Destructive, so a UI should confirm before this is called.
    @discardableResult
    public func deleteTeam(id: String) async throws -> CreatedTeam {
        try await rest.send(
            CreatedTeam.self,
            method: "DELETE",
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(id))",
            body: EmptyBody()
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

    /// Adds an existing user to a team (`POST /teams/{team_id}/users/{user_id}?license=`).
    @discardableResult
    public func addTeamMember(teamID: String, userID: String, license: String? = nil) async throws
        -> TeamMembershipResult {
        var components = URLComponents(
            url: baseURL.appending(
                path: "\(Self.apiV3)/teams/\(Self.pathSegment(teamID))/users/\(Self.pathSegment(userID))"
            ),
            resolvingAgainstBaseURL: false
        )
        if let license = Self.nonBlank(license) {
            components?.queryItems = [URLQueryItem(name: "license", value: license)]
        }
        guard let url = components?.url else {
            throw HackerRankError.http(0, "Could not build the team membership URL.")
        }
        let request = RESTRequest(
            url: url,
            method: "POST",
            headers: [
                "Authorization": "Bearer \(token)",
                "Accept": "application/json",
                "Content-Type": "application/json"
            ],
            body: try Self.makeEncoder().encode(EmptyBody())
        )
        return try await rest.perform(TeamMembershipResult.self, request: request)
    }

    /// Retrieves a team membership (`GET /teams/{team_id}/users/{user_id}`).
    public func teamMembership(teamID: String, userID: String) async throws -> TeamMembershipResult {
        try await rest.fetch(
            TeamMembershipResult.self,
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(teamID))/users/\(Self.pathSegment(userID))"
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

    /// Sends a request whose successful response may be empty (for example SCIM 204 deletes).
    private func sendNoContent(method: String, path: String) async throws {
        guard !token.isEmpty else { throw HackerRankError.missingAPIKey }

        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.makeEncoder().encode(EmptyBody())

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw HackerRankError.network(urlError)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(status) else {
            throw HackerRankError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// Builds an offset-paginated URL for legacy endpoints that do not return a `next` cursor.
    nonisolated func offsetURL(path: String, limit: Int, offset: Int) throws -> URL {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        guard let url = components?.url else {
            throw HackerRankError.http(0, "Could not build the offset-paginated URL.")
        }
        return url
    }

    /// The absolute `cursor` URL when continuing, or the first-page URL (base + path +
    /// `limit`, plus any endpoint-specific `query`) when starting.
    nonisolated func pageURL(path: String, cursor: String?, query: [URLQueryItem] = []) throws -> URL {
        if let cursor {
            guard let url = cursorURL(cursor) else {
                throw HackerRankError.http(0, "Invalid next-page URL: \(cursor)")
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

    /// Parses a server-provided pagination link. The strict parser rejects links the
    /// server can hand back in practice (e.g. an unencoded space where a search link
    /// echoes the query), and some deployments return links relative to the API host;
    /// tolerate both rather than failing the page.
    nonisolated func cursorURL(_ cursor: String) -> URL? {
        let trimmed = cursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed, encodingInvalidCharacters: true) else { return nil }
        guard url.scheme == nil else { return url }

        return URL(string: url.relativeString, relativeTo: baseURL)?.absoluteURL
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
