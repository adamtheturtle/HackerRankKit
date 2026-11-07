import Foundation

/// Availability and a temporary signed URL. Unknown states are retained for forward compatibility.
public nonisolated struct InterviewArtifactDescriptor: Codable, Hashable, Sendable {
    public let state: String
    public let location: String?
}

/// One question tab in saved order. Unknown artifact names are retained in the dictionary.
public nonisolated struct InterviewArtifactQuestion: Codable, Hashable, Sendable {
    public let tabID: String
    public let questionSequence: Int
    public let libraryQuestionID: String?
    public let qtype: String
    public let questionName: String?
    public let problemStatement: String?
    public let roleType: String?
    public let projectMode: String?
    public let artifacts: [String: InterviewArtifactDescriptor]

    enum CodingKeys: String, CodingKey {
        case tabID = "tab_id", questionSequence = "question_sequence", libraryQuestionID = "library_question_id"
        case qtype, artifacts
        case questionName = "question_name", problemStatement = "problem_statement"
        case roleType = "role_type", projectMode = "project_mode"
    }
}

/// A note reference returned with artifacts, without its content.
public nonisolated struct InterviewArtifactNote: Codable, Hashable, Sendable {
    public let noteID: Int
    public let evaluatorID: Int

    enum CodingKeys: String, CodingKey {
        case noteID = "note_id", evaluatorID = "evaluator_id"
    }
}

/// Metadata for an ended Interviews V2 interview. Empty arrays and unavailable artifacts are valid.
public nonisolated struct InterviewArtifacts: Codable, Hashable, Sendable {
    public let interviewID: String
    public let transcriptURL: InterviewArtifactDescriptor
    public let interviewerNotes: [InterviewArtifactNote]
    public let questions: [InterviewArtifactQuestion]

    enum CodingKeys: String, CodingKey {
        case interviewID = "interview_id", transcriptURL = "transcript_url"
        case interviewerNotes = "interviewer_notes", questions
    }
}

/// The generation-window response. Request again after the server's delay; this result is not an error.
public nonisolated struct InterviewArtifactsPending: Codable, Hashable, Sendable {
    public let message: String
    public let retryAfter: Int?
}

/// Distinguishes HTTP 200 metadata from the HTTP 202 generation window.
public nonisolated enum InterviewArtifactsResult: Sendable {
    case available(InterviewArtifacts)
    case pending(InterviewArtifactsPending)
}

/// A note visible to the caller. PATCH returns only content and updated_at.
public nonisolated struct InterviewNote: Codable, Hashable, Sendable, Identifiable {
    public let noteID: Int?
    public let evaluatorID: Int?
    public let evaluatorName: String?
    public let content: String?
    public let updatedAt: String?
    public let editable: Bool?

    public var id: Int? {
        noteID
    }

    enum CodingKeys: String, CodingKey {
        case noteID = "note_id", evaluatorID = "evaluator_id", evaluatorName = "evaluator_name"
        case content, updatedAt = "updated_at", editable
    }
}

extension HackerRankClient {
    /// Retrieves existing artifact metadata without starting generation or downloading signed URLs.
    /// This uses URLSession directly because the shared transport does not expose response headers.
    public func interviewArtifacts(id: String) async throws -> InterviewArtifactsResult {
        guard !token.isEmpty else { throw HackerRankError.missingAPIKey }

        var request = URLRequest(url: try url(path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))/artifacts"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw HackerRankError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw HackerRankError.http(0, "Missing HTTP response")
        }
        guard http.statusCode == 200 || http.statusCode == 202 else {
            throw HackerRankError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            let decoder = JSONDecoder()
            if http.statusCode == 202 {
                nonisolated struct Pending: Decodable { let message: String }
                let pending = try decoder.decode(Pending.self, from: data)
                return .pending(InterviewArtifactsPending(
                    message: pending.message,
                    retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                ))
            }
            return .available(try decoder.decode(InterviewArtifacts.self, from: data))
        } catch {
            throw HackerRankError.decode(String(describing: error))
        }
    }

    /// Retrieves permitted notes, optionally restricted to the supplied IDs (Swagger CSV encoding).
    public func interviewNotes(id: String, noteIDs: [Int]? = nil) async throws -> [InterviewNote] {
        nonisolated struct Notes: Decodable, Sendable { let notes: [InterviewNote] }
        let query = noteIDs.map { ids in
            [URLQueryItem(name: "note_ids", value: ids.map(String.init).joined(separator: ","))]
        } ?? []
        return try await fetch(
            Notes.self, path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))/notes", query: query
        ).notes
    }

    /// Replaces the current user's note; an empty string clears the content.
    public func updateInterviewNote(id: String, content: String) async throws -> InterviewNote {
        nonisolated struct Body: Encodable { let content: String }
        return try await send(
            InterviewNote.self, method: "PATCH", path: "\(Self.apiV3)/interviews/\(Self.pathSegment(id))/notes",
            body: Body(content: content)
        )
    }

    /// Adds accessible question IDs. This endpoint does not guarantee ordering.
    public func addQuestionsToInterviewTemplate(id: Int, questionIDs: [Int]) async throws -> InterviewTemplate {
        try await send(
            InterviewTemplate.self, method: "PUT", path: "\(Self.apiV3)/interview_templates/\(id)/add_questions",
            body: InterviewTemplateQuestionsBody(questionIDs: questionIDs)
        )
    }

    /// Removes one question using the documented query parameter, rather than a DELETE body.
    public func removeQuestionFromInterviewTemplate(id: Int, questionID: Int) async throws -> InterviewTemplate {
        try await send(
            InterviewTemplate.self, method: "DELETE", path: "\(Self.apiV3)/interview_templates/\(id)/remove_question",
            query: [URLQueryItem(name: "question_id", value: String(questionID))], body: EmptyBody()
        )
    }
}

private nonisolated struct InterviewTemplateQuestionsBody: Encodable {
    let questionIDs: [Int]
    enum CodingKeys: String, CodingKey { case questionIDs = "question_ids" }
}
