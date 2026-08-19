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
    ///
    /// Several of the fields this read is called for — the per-question scores, the attempt
    /// events, the report comments, the IP address — are opt-in: the server omits them
    /// unless they are named in `additional_fields`. They are requested by default, since
    /// this method exists to return more than the list row already carries. Pass `[]` for
    /// the lighter response.
    public func candidate(
        testID: String,
        candidateID: String,
        additionalFields: [String] = TestCandidate.detailAdditionalFields
    ) async throws -> TestCandidate {
        try await fetch(
            TestCandidate.self,
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))",
            query: Self.additionalFieldsQuery(additionalFields)
        )
    }

    /// Updates candidate metadata/invite settings (`PUT /tests/{test_id}/candidates/{candidate_id}`).
    @discardableResult
    public func updateCandidate(
        testID: String,
        candidateID: String,
        options: CandidateUpdateOptions = CandidateUpdateOptions()
    ) async throws -> TestCandidate {
        try await send(
            TestCandidate.self,
            method: "PUT",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))",
            body: UpdateCandidateRequest(options: options)
        )
    }

    /// Cancels an outstanding candidate invite (`DELETE /tests/{test_id}/candidates/{candidate_id}/invite`).
    @discardableResult
    public func cancelCandidateInvite(testID: String, candidateID: String) async throws -> CandidateWriteResult {
        try await send(
            CandidateWriteResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))/invite",
            body: EmptyBody()
        )
    }

    /// Fetches the URL for a candidate's report PDF (`GET /tests/{test_id}/candidates/{candidate_id}/pdf?format=url`).
    public func candidateReportPDF(testID: String, candidateID: String) async throws -> CandidateReportPDF {
        try await fetch(
            CandidateReportPDF.self,
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates/\(Self.pathSegment(candidateID))/pdf",
            query: [URLQueryItem(name: "format", value: "url")]
        )
    }

    /// Deletes a candidate report (`DELETE /tests/{test_id}/candidates/{candidate_id}/report`).
    @discardableResult
    public func deleteCandidateReport(testID: String, candidateID: String) async throws -> CandidateWriteResult {
        try await send(
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
        return try await send(
            InvitedCandidate.self,
            method: "POST",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/candidates",
            body: body
        )
    }

    /// Creates a test (`POST /tests`).
    ///
    /// `duration`, `roleIDs`, and `experience` are parameters rather than options because
    /// `TestsCreate` requires them alongside the name: a body carrying only a name is
    /// rejected by the live API. Any values `options` also carries for those three fields
    /// apply to updates only and are not sent here.
    @discardableResult
    public func createTest(
        name: String,
        duration: Int,
        roleIDs: [String],
        experience: [String],
        options: TestWriteOptions = TestWriteOptions()
    ) async throws -> CreatedTest {
        let body = CreateTestRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: duration,
            roleIDs: roleIDs,
            experience: experience,
            options: options
        )
        return try await send(CreatedTest.self, method: "POST", path: "\(Self.apiV3)/tests", body: body)
    }

    /// Archives a test (`POST /tests/{id}/archive`).
    ///
    /// The endpoint answers 204 No Content, so there is nothing to decode: returning
    /// normally means the archive succeeded.
    public func archiveTest(testID: String) async throws {
        try await sendNoContent(
            method: "POST",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))/archive"
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
        return try await send(
            CreatedTest.self,
            method: "PUT",
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))",
            body: body
        )
    }

    /// Permanently deletes a test (`DELETE /tests/{id}`). Destructive and irreversible,
    /// so a UI should confirm before this is called.
    ///
    /// The endpoint answers 204 No Content. Decoding a record from that empty body reported
    /// failure *after* an irreversible deletion had already succeeded, which invites a
    /// retry of something that cannot be retried.
    public func deleteTest(testID: String) async throws {
        try await sendNoContent(method: "DELETE", path: "\(Self.apiV3)/tests/\(Self.pathSegment(testID))")
    }

    /// The richer single-test read (`GET /tests/{id}`) backing a detail view. Adds the
    /// candidate login links, the master password, and the MCQ scoring over the list row.
    ///
    /// Every one of those is an opt-in field: without naming them in `additional_fields`
    /// the server returns a response in which each is absent, so the read added nothing.
    /// The fields ``TestDetail`` models are requested by default; pass `[]` for the
    /// lighter response.
    public func test(
        id: String,
        additionalFields: [String] = TestDetail.detailAdditionalFields
    ) async throws -> TestDetail {
        try await fetch(
            TestDetail.self,
            path: "\(Self.apiV3)/tests/\(Self.pathSegment(id))",
            query: Self.additionalFieldsQuery(additionalFields)
        )
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

    /// The single-question read (`GET /questions/{id}`). Returns the whole `QuestionShow`
    /// resource — the list row's fields plus the MCQ options/answer and internal notes — so
    /// a detail refresh can replace a stale row rather than only annotate one.
    public func question(id: String) async throws -> QuestionDetail {
        try await fetch(QuestionDetail.self, path: "\(Self.apiV3)/questions/\(Self.pathSegment(id))")
    }

    /// Creates a question (`POST /questions`).
    ///
    /// `problemStatement` and `recommendedDuration` are parameters rather than options
    /// because `QuestionCreate` requires them alongside the name and type: a body carrying
    /// only a name and a type is rejected by the live API. For an `mcq`, pass the choices
    /// and the correct answer through `options`.
    @discardableResult
    public func createQuestion(
        name: String,
        type: String,
        problemStatement: String,
        recommendedDuration: Int,
        options: QuestionWriteOptions = QuestionWriteOptions()
    ) async throws -> WrittenQuestion {
        let body = CreateQuestionRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type.trimmingCharacters(in: .whitespacesAndNewlines),
            problemStatement: problemStatement,
            recommendedDuration: recommendedDuration,
            options: options
        )
        return try await send(WrittenQuestion.self, method: "POST", path: "\(Self.apiV3)/questions", body: body)
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
        return try await send(
            WrittenQuestion.self,
            method: "PUT",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))",
            body: body
        )
    }

    /// Updates a coding question's custom code stubs (`PUT /questions/{id}/custom_codestubs`).
    @discardableResult
    public func updateCustomCodeStubs(
        questionID: String,
        stubs: [QuestionCodeStub]
    ) async throws -> QuestionOperationResult {
        try await send(
            QuestionOperationResult.self,
            method: "PUT",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/custom_codestubs",
            body: CustomCodeStubsRequest(stubs: stubs)
        )
    }

    /// Generates code stubs for a coding question (`PUT /questions/{id}/generate`).
    ///
    /// Returns the generated templates. The endpoint answers with the signature it used and
    /// one head/body/tail template per requested language — none of which is a status
    /// acknowledgement, so decoding one discarded every generated stub.
    @discardableResult
    public func generateCodeStubs(
        questionID: String,
        options: CodeStubGenerationOptions = CodeStubGenerationOptions()
    ) async throws -> GeneratedCodeStubs {
        try await send(
            GeneratedCodeStubs.self,
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
        try await send(
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
        try await send(
            QuestionOperationResult.self,
            method: "PUT",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/testcases/\(Self.pathSegment(testcaseID))",
            body: QuestionTestcaseRequest(options: options)
        )
    }

    /// Deletes a testcase (`DELETE /questions/{id}/testcases/{testcase_id}`).
    @discardableResult
    public func deleteTestcase(questionID: String, testcaseID: String) async throws -> QuestionOperationResult {
        try await send(
            QuestionOperationResult.self,
            method: "DELETE",
            path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))/testcases/\(Self.pathSegment(testcaseID))",
            body: EmptyBody()
        )
    }

    /// Deletes all testcases for a question (`DELETE /questions/{id}/testcases/delete_all`).
    @discardableResult
    public func deleteAllTestcases(questionID: String) async throws -> QuestionOperationResult {
        try await send(
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
    ///
    /// An interview created with a title and no scheduled window is the instant pad. The
    /// create schema has no `quickpad` property, so the body carries only the title.
    @discardableResult
    public func createQuickPad(title: String? = nil) async throws -> CreatedInterview {
        // The API rejects a titleless interview with HTTP 400, so fall back to a dated
        // default rather than surfacing an error for an optional title.
        let body = CreateQuickPadRequest(title: Self.nonBlank(title) ?? Self.defaultQuickPadTitle())
        return try await send(CreatedInterview.self, method: "POST", path: "\(Self.apiV3)/interviews", body: body)
    }

    /// Creates an instant Pad collaborative interview.
    ///
    /// Alias for `createQuickPad(title:)` retained for app call sites that use the product-facing
    /// "Pad" naming.
    @discardableResult
    public func createPad(title: String? = nil) async throws -> CreatedInterview {
        try await createQuickPad(title: title)
    }

    /// Schedules an interview (`POST /interviews`). The scheduled window is sent as
    /// ISO-8601 timestamps.
    ///
    /// The candidate is an object, not a bare email: the schema carries their name
    /// alongside the address. `interviewers` takes the emails (or ids) to invite.
    @discardableResult
    public func scheduleInterview(
        title: String,
        from: Date,
        to: Date? = nil,
        candidate: InterviewCandidate? = nil,
        interviewers: [String] = [],
        notes: String? = nil
    ) async throws -> CreatedInterview {
        let formatter = ISO8601DateFormatter()
        let cleanedInterviewers = interviewers.compactMap(Self.nonBlank)
        let body = ScheduleInterviewRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            from: formatter.string(from: from),
            to: to.map(formatter.string(from:)),
            candidate: candidate,
            interviewers: cleanedInterviewers.isEmpty ? nil : cleanedInterviewers,
            notes: Self.nonBlank(notes)
        )
        return try await send(CreatedInterview.self, method: "POST", path: "\(Self.apiV3)/interviews", body: body)
    }

    /// The richer single-interview read (`GET /interviews/{id}`) backing a detail view.
    /// Adds the scheduled window, interviewers, owner, candidate, and result/résumé links.
    public func interview(id: String) async throws -> InterviewDetail {
        try await fetch(InterviewDetail.self, path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))")
    }

    /// Updates an interview (`PUT /interviews/{id}`).
    @discardableResult
    public func updateInterview(
        id: String,
        options: InterviewUpdateOptions = InterviewUpdateOptions()
    ) async throws -> CreatedInterview {
        try await send(
            CreatedInterview.self,
            method: "PUT",
            path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))",
            body: UpdateInterviewRequest(options: options)
        )
    }

    /// Deletes an interview (`DELETE /interviews/{id}`). Destructive, so a UI should confirm before this is called.
    @discardableResult
    public func deleteInterview(id: String) async throws -> CreatedInterview {
        try await send(
            CreatedInterview.self,
            method: "DELETE",
            path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))",
            body: EmptyBody()
        )
    }

    /// The interview's conversation transcript (`GET /interviews/{id}/transcript`) — the
    /// spoken/typed messages only; the collaborative pad's source code is not exposed.
    public func interviewTranscript(id: String) async throws -> InterviewTranscript {
        try await fetch(
            InterviewTranscript.self,
            path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))/transcript"
        )
    }

    // MARK: Interview templates

    /// One page of interview templates (`GET /interview_templates`), optionally narrowed to
    /// the templates the current user owns or the ones shared with them.
    public func interviewTemplatesPage(
        after cursor: String? = nil,
        filter: InterviewTemplateFilter? = nil
    ) async throws -> Page<InterviewTemplate> {
        try await page(
            HackerRankPage<InterviewTemplate>.self,
            path: "\(Self.apiV3)/interview_templates",
            cursor: cursor,
            query: filter.map { [URLQueryItem(name: "filter", value: $0.rawValue)] } ?? []
        )
    }

    /// Shows an interview template (`GET /interview_templates/{template_id}`).
    public func interviewTemplate(id: Int) async throws -> InterviewTemplate {
        try await fetch(InterviewTemplate.self, path: "\(Self.apiV3)/interview_templates/\(id)")
    }

    /// Creates an interview template (`POST /interview_templates`). The name is the only
    /// field the endpoint requires.
    @discardableResult
    public func createInterviewTemplate(
        name: String,
        options: InterviewTemplateCreateOptions = InterviewTemplateCreateOptions()
    ) async throws -> InterviewTemplate {
        try await send(
            InterviewTemplate.self,
            method: "POST",
            path: "\(Self.apiV3)/interview_templates",
            body: CreateInterviewTemplateRequest(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines), options: options
            )
        )
    }

    /// Updates an interview template (`PUT /interview_templates/{template_id}`). Only the
    /// fields supplied are sent; the server leaves everything else unchanged.
    @discardableResult
    public func updateInterviewTemplate(
        id: Int,
        options: InterviewTemplateUpdateOptions = InterviewTemplateUpdateOptions()
    ) async throws -> InterviewTemplate {
        try await send(
            InterviewTemplate.self,
            method: "PUT",
            path: "\(Self.apiV3)/interview_templates/\(id)",
            body: UpdateInterviewTemplateRequest(options: options)
        )
    }

    /// Deletes an interview template (`DELETE /interview_templates/{template_id}`).
    @discardableResult
    public func deleteInterviewTemplate(id: Int) async throws -> InterviewTemplateWriteResult {
        try await send(
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
        try await fetch(InviteTemplate.self, path: "\(Self.apiV3)/templates/\(Self.pathSegment(id))")
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
        return try await send(ATSInviteResult.self, method: "POST", path: "\(Self.apiV3)/ats/codepair", body: body)
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
        return try await send(
            ATSInviteResult.self, method: "POST", path: "\(Self.apiV3)/ats/codescreen", body: body
        )
    }

    // MARK: SCIM provisioning

    /// Lists users from the legacy SCIM provisioning endpoint (`GET /Users`).
    public func scimUsers(limit: Int = 100, offset: Int = 0) async throws -> SCIMListResponse<SCIMUser> {
        let url = try offsetURL(path: "/Users", limit: limit, offset: offset)
        return try await rest.performWithRetry(SCIMListResponse<SCIMUser>.self, request: try authorizedGET(url))
    }

    /// Retrieves a user from the legacy SCIM provisioning endpoint (`GET /Users/{id}`).
    public func scimUser(id: String) async throws -> SCIMUser {
        try await fetch(SCIMUser.self, path: "/Users/\(Self.pathSegment(id))")
    }

    /// Creates a user through the legacy SCIM provisioning endpoint (`POST /Users`).
    @discardableResult
    public func createSCIMUser(body: SCIMUserWriteRequest) async throws -> SCIMUser {
        try await send(SCIMUser.self, method: "POST", path: "/Users", body: body)
    }

    /// Replaces a user through the legacy SCIM provisioning endpoint (`PUT /Users/{id}`).
    @discardableResult
    public func updateSCIMUser(id: String, body: SCIMUserWriteRequest) async throws -> SCIMUser {
        try await send(SCIMUser.self, method: "PUT", path: "/Users/\(Self.pathSegment(id))", body: body)
    }

    /// Patches a user through the legacy SCIM provisioning endpoint (`PATCH /Users/{id}`).
    @discardableResult
    public func patchSCIMUser(id: String, body: SCIMPatchRequest) async throws -> SCIMUser {
        try await send(SCIMUser.self, method: "PATCH", path: "/Users/\(Self.pathSegment(id))", body: body)
    }

    /// Locks a user through the legacy SCIM provisioning endpoint (`DELETE /Users/{id}`).
    public func lockSCIMUser(id: String) async throws {
        try await sendNoContent(method: "DELETE", path: "/Users/\(Self.pathSegment(id))")
    }

    /// Lists groups from the legacy SCIM provisioning endpoint (`GET /Groups`).
    public func scimGroups(limit: Int = 100, offset: Int = 0) async throws -> SCIMListResponse<SCIMGroup> {
        let url = try offsetURL(path: "/Groups", limit: limit, offset: offset)
        return try await rest.performWithRetry(SCIMListResponse<SCIMGroup>.self, request: try authorizedGET(url))
    }

    /// Retrieves a group from the legacy SCIM provisioning endpoint (`GET /Groups/{id}`).
    public func scimGroup(id: String) async throws -> SCIMGroup {
        try await fetch(SCIMGroup.self, path: "/Groups/\(Self.pathSegment(id))")
    }

    /// Creates a group through the legacy SCIM provisioning endpoint (`POST /Groups`).
    @discardableResult
    public func createSCIMGroup(body: SCIMGroupWriteRequest) async throws -> SCIMGroup {
        try await send(SCIMGroup.self, method: "POST", path: "/Groups", body: body)
    }

    /// Patches a group through the legacy SCIM provisioning endpoint (`PATCH /Groups/{id}`).
    @discardableResult
    public func patchSCIMGroup(id: String, body: SCIMPatchRequest) async throws -> SCIMGroup {
        try await send(SCIMGroup.self, method: "PATCH", path: "/Groups/\(Self.pathSegment(id))", body: body)
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
    /// `UserCreate` requires `email`, `firstname`, `role`, and at least one team, so all
    /// four are parameters: defaulting them built a body the server rejects with HTTP 400
    /// ("Parameter teams is required") after a round trip. Blank values and an empty team
    /// list are rejected locally for the same reason.
    ///
    /// - Throws: ``HackerRankError/http(_:_:)`` with status 0 when a required value is
    ///   blank or no team is given, before any request is made.
    @discardableResult
    public func createUser(
        email: String,
        firstName: String,
        role: String,
        teamIDs: [String],
        lastName: String? = nil
    ) async throws -> CreatedUser {
        let teams = teamIDs.compactMap(Self.nonBlank)
        guard let email = Self.nonBlank(email),
              let firstName = Self.nonBlank(firstName),
              let role = Self.nonBlank(role),
              !teams.isEmpty else {
            throw HackerRankError.http(0, "Creating a user needs an email, a first name, a role, and a team.")
        }

        let body = CreateUserRequest(
            email: email,
            firstName: firstName,
            lastName: Self.nonBlank(lastName),
            role: role,
            teams: teams.map(CreateUserRequest.TeamRef.init)
        )
        return try await send(CreatedUser.self, method: "POST", path: "\(Self.apiV3)/users", body: body)
    }

    /// Retrieves a user by id (`GET /users/{id}`).
    public func user(id: String) async throws -> User {
        try await fetch(User.self, path: "\(Self.apiV3)/users/\(Self.pathSegment(id))")
    }

    /// Updates a user (`PUT /users/{id}`).
    @discardableResult
    public func updateUser(id: String, options: UserUpdateOptions = UserUpdateOptions()) async throws -> User {
        try await send(
            User.self,
            method: "PUT",
            path: "\(Self.apiV3)/users/\(Self.pathSegment(id))",
            body: UpdateUserRequest(options: options)
        )
    }

    /// Locks a user (`DELETE /users/{id}`).
    ///
    /// The endpoint answers 204 No Content, so returning normally means the user was locked.
    public func lockUser(id: String) async throws {
        try await sendNoContent(method: "DELETE", path: "\(Self.apiV3)/users/\(Self.pathSegment(id))")
    }

    /// The user the token belongs to (`GET /users/me`). Used to auto-discover an
    /// account's identity. Returns a single user object (not a paged envelope).
    public func currentUser() async throws -> User {
        try await fetch(User.self, path: "\(Self.apiV3)/users/me")
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
        try await fetch(Team.self, path: "\(Self.apiV3)/teams/\(Self.pathSegment(id))")
    }

    /// Updates a team (`PUT /teams/{id}`).
    @discardableResult
    public func updateTeam(id: String, options: TeamUpdateOptions = TeamUpdateOptions()) async throws -> Team {
        try await send(
            Team.self,
            method: "PUT",
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(id))",
            body: UpdateTeamRequest(options: options)
        )
    }

    /// Deletes a team (`DELETE /teams/{id}`). Destructive, so a UI should confirm before this is called.
    @discardableResult
    public func deleteTeam(id: String) async throws -> CreatedTeam {
        try await send(
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
        return try await send(CreatedTeam.self, method: "POST", path: "\(Self.apiV3)/teams", body: body)
    }

    /// Adds an existing user to a team (`POST /teams/{team_id}/users/{user_id}?license=`).
    ///
    /// Membership is granted to a user who already exists. There is no by-email collection
    /// POST: create the user with ``createUser(email:firstName:lastName:role:teamIDs:)``
    /// first, which takes the teams to place them in.
    @discardableResult
    public func addTeamMember(teamID: String, userID: String, license: String? = nil) async throws
        -> TeamMembershipResult {
        try await send(
            TeamMembershipResult.self,
            method: "POST",
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(teamID))/users/\(Self.pathSegment(userID))",
            query: Self.nonBlank(license).map { [URLQueryItem(name: "license", value: $0)] } ?? [],
            body: EmptyBody()
        )
    }

    /// Retrieves a team membership (`GET /teams/{team_id}/users/{user_id}`).
    public func teamMembership(teamID: String, userID: String) async throws -> TeamMembershipResult {
        try await fetch(
            TeamMembershipResult.self,
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(teamID))/users/\(Self.pathSegment(userID))"
        )
    }

    /// Removes a member from a team (`DELETE /teams/{id}/users/{userID}`). Destructive,
    /// so a UI should confirm before this is called.
    ///
    /// The endpoint answers 204 No Content, so returning normally means access was revoked.
    public func removeTeamMember(teamID: String, userID: String) async throws {
        try await sendNoContent(
            method: "DELETE",
            path: "\(Self.apiV3)/teams/\(Self.pathSegment(teamID))/users/\(Self.pathSegment(userID))"
        )
    }

    // MARK: Token validation

    /// Lightweight token validation: requests a single test. A 2xx response (even with
    /// no tests) means the token authenticates; an auth failure throws
    /// ``HackerRankError/http(_:_:)`` with a 401/403 status. Throws before any request
    /// when the token is empty.
    public func validateToken() async throws {
        guard !token.isEmpty else { throw HackerRankError.missingAPIKey }

        let url = try url(path: "\(Self.apiV3)/tests", query: [URLQueryItem(name: "limit", value: "1")])
        _ = try await rest.performWithRetry(HackerRankPage<Test>.self, request: try authorizedGET(url))
    }

    // MARK: - URL building

    /// Builds an absolute request URL from an **already percent-encoded** `path` and a set of
    /// *unencoded* query items.
    ///
    /// Every request in this client goes through here rather than `URL.appending(path:)`.
    /// `appending(path:)` percent-encodes whatever it is handed, so a path whose dynamic ids
    /// have already been escaped by ``pathSegment(_:)`` would be encoded a *second* time —
    /// `%40` becoming `%2540`, so the server sees the literal text `%40` instead of `@` and
    /// the request addresses the wrong resource (or 404s). Assembling the URL from the
    /// pre-encoded path applies exactly one encoding.
    ///
    /// The query is encoded by ``queryComponent(_:)`` rather than by `URLComponents`, which
    /// leaves `+` untouched (see that method).
    nonisolated func url(path: String, query: [URLQueryItem] = []) throws -> URL {
        var text = baseURL.absoluteString
        while text.hasSuffix("/") {
            text.removeLast()
        }
        text += path.hasPrefix("/") ? path : "/\(path)"
        if !query.isEmpty {
            text += "?" + query.map { item in
                let name = Self.queryComponent(item.name)
                guard let value = item.value else { return name }

                return "\(name)=\(Self.queryComponent(value))"
            }
            .joined(separator: "&")
        }
        guard let url = URL(string: text) else {
            throw HackerRankError.http(0, "Could not build the URL for \(path).")
        }

        return url
    }

    /// Builds the authorized GET for `url`, rejecting an unset token first.
    ///
    /// **Every** authenticated read goes through here. Calling the transport's
    /// `authorizedGET` directly skipped the check, so whether a tokenless client failed
    /// locally with ``HackerRankError/missingAPIKey`` or made a request with an empty
    /// `Authorization: Bearer` header and reported the server's rejection depended on which
    /// method the caller happened to use.
    nonisolated func authorizedGET(_ url: URL) throws -> RESTRequest {
        guard !token.isEmpty else { throw HackerRankError.missingAPIKey }

        return rest.authorizedGET(url)
    }

    /// GETs `path` (already percent-encoded) with retries, as ``rest``'s own `fetch` would,
    /// but building the URL through ``url(path:query:)`` so the path is encoded exactly once.
    private func fetch<T: Decodable & Sendable>(
        _ type: T.Type,
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> T {
        try await rest.performWithRetry(type, request: try authorizedGET(try url(path: path, query: query)))
    }

    /// Sends a request with a JSON body to `path` (already percent-encoded), as ``rest``'s own
    /// `send` would, but building the URL through ``url(path:query:)``. Mutating requests are
    /// not retried, so this goes straight to `perform`.
    private func send<T: Decodable & Sendable>(
        _ type: T.Type,
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: some Encodable
    ) async throws -> T {
        guard !token.isEmpty else { throw HackerRankError.missingAPIKey }

        let request = RESTRequest(
            url: try url(path: path, query: query),
            method: method,
            headers: [
                "Authorization": "Bearer \(token)",
                "Accept": "application/json",
                "Content-Type": "application/json"
            ],
            body: try Self.makeEncoder().encode(body)
        )
        return try await rest.perform(type, request: request)
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
        let response = try await rest.performWithRetry(HackerRankPage<Item>.self, request: try authorizedGET(url))
        return Page(items: response.data, next: response.next, totalCount: response.totalCount)
    }

    /// Sends a request whose successful response may be empty (for example SCIM 204 deletes).
    private func sendNoContent(method: String, path: String) async throws {
        guard !token.isEmpty else { throw HackerRankError.missingAPIKey }

        var request = URLRequest(url: try url(path: path))
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
        try url(path: path, query: [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ])
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

        return try url(path: path, query: [URLQueryItem(name: "limit", value: String(Self.pageSize))] + query)
    }

    /// Parses a server-provided pagination link. The strict parser rejects links the
    /// server can hand back in practice (e.g. an unencoded space where a search link
    /// echoes the query), and some deployments return links relative to the API host;
    /// tolerate both rather than failing the page.
    ///
    /// The result is **constrained to ``baseURL``'s origin** (scheme, host, and port). A
    /// cursor is server-supplied data, and the next request carries the account's Bearer
    /// token unconditionally, so an absolute `next` link naming another host would hand the
    /// user's personal access token to that host. A cursor that leaves the origin is rejected
    /// (`nil`, which the callers surface as an invalid-cursor error) rather than followed.
    nonisolated func cursorURL(_ cursor: String) -> URL? {
        let trimmed = cursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed, encodingInvalidCharacters: true) else { return nil }

        // A relative cursor resolves against `baseURL`, so it is in-origin by construction;
        // an absolute one has to be checked.
        let resolved = parsed.scheme == nil
            ? URL(string: parsed.relativeString, relativeTo: baseURL)?.absoluteURL
            : parsed
        guard let resolved, Self.sameOrigin(resolved, baseURL) else { return nil }

        return resolved
    }

    /// Whether two URLs share an origin — scheme, host, and port. Scheme and host are
    /// case-insensitive per RFC 3986; the port falls back to the scheme's default so
    /// `https://host` and `https://host:443` compare equal.
    nonisolated static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        func port(of url: URL) -> Int? {
            url.port ?? (url.scheme?.lowercased() == "https" ? 443 : url.scheme?.lowercased() == "http" ? 80 : nil)
        }

        guard let leftHost = lhs.host(), let rightHost = rhs.host() else { return false }

        return lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && leftHost.caseInsensitiveCompare(rightHost) == .orderedSame
            && port(of: lhs) == port(of: rhs)
    }

    /// The `additional_fields` query for a detail read: the API takes the opt-in field
    /// names as one comma-separated value. An empty list sends no parameter at all.
    nonisolated static func additionalFieldsQuery(_ fields: [String]) -> [URLQueryItem] {
        let cleaned = fields.compactMap(nonBlank)
        guard !cleaned.isEmpty else { return [] }

        return [URLQueryItem(name: "additional_fields", value: cleaned.joined(separator: ","))]
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
    ///
    /// This is the **only** encoding applied to a path: the result is assembled into a URL by
    /// ``url(path:query:)``, which does not re-encode. Sub-delimiters and `/` are escaped so
    /// an id can never break out of its segment or be reinterpreted by the server.
    nonisolated static func pathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// Percent-encodes a query-string name or value.
    ///
    /// `URLComponents.queryItems` escapes `&`, `=`, `#`, spaces, and non-ASCII, but leaves `+`
    /// alone — and the API's Rack/Rails query parser decodes a literal `+` as a space, so
    /// `C++` would be searched for as `C` followed by two spaces and a plus-addressed email
    /// would lose its tag. `+` is escaped explicitly here, matching the exclusion
    /// ``pathSegment(_:)`` already makes, so a query value survives the round trip verbatim.
    nonisolated static func queryComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?#")
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
        let normalizedNext = next?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.next = normalizedNext?.isEmpty == false ? normalizedNext : nil
        self.totalCount = totalCount
    }
}
