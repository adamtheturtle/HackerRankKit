import Foundation

/// Selected metadata replacements. A nil field preserves its current value.
/// Empty strings and lists, and a duration of zero, are explicit values.
/// The question's identity remains unchanged. Its type is preserved unless selected.
public nonisolated struct QuestionMetadataChanges: Sendable {
    public let name: String?
    public let type: String?
    public let internalNotes: String?
    public let languages: [String]?
    public let problemStatement: String?
    public let recommendedDuration: Int?
    public let tags: [String]?
    public let options: [String]?
    public let answer: QuestionAnswer?
    public let customSystemPrompt: String?

    public init(
        name: String? = nil,
        type: String? = nil,
        internalNotes: String? = nil,
        languages: [String]? = nil,
        problemStatement: String? = nil,
        recommendedDuration: Int? = nil,
        tags: [String]? = nil,
        options: [String]? = nil,
        answer: QuestionAnswer? = nil,
        customSystemPrompt: String? = nil
    ) {
        self.name = name
        self.type = type
        self.internalNotes = internalNotes
        self.languages = languages
        self.problemStatement = problemStatement
        self.recommendedDuration = recommendedDuration
        self.tags = tags
        self.options = options
        self.answer = answer
        self.customSystemPrompt = customSystemPrompt
    }

    fileprivate func body(current: QuestionMetadataSnapshot) throws -> HackerRankJSONValue {
        guard let statement = problemStatement ?? current.question.problemStatement,
              let duration = recommendedDuration ?? current.question.recommendedDuration else {
            throw EncodingError.invalidValue(current.question.id, .init(
                codingPath: [], debugDescription: "The question lacks required statement or duration metadata."
            ))
        }
        let effectiveType = type ?? current.question.type
        try QuestionPromptValidation.validate(type: effectiveType, prompt: customSystemPrompt)
        var fields: [String: HackerRankJSONValue] = [
            "name": .string(name ?? current.question.name),
            "type": .string(effectiveType),
            "internal_notes": .string(internalNotes ?? current.internalNotes ?? ""),
            "languages": .array((languages ?? current.question.languages ?? []).map(HackerRankJSONValue.string)),
            "problem_statement": .string(statement),
            "recommended_duration": .int(duration),
            "tags": .array((tags ?? current.question.tags ?? []).map(HackerRankJSONValue.string)),
            "options": .array((options ?? current.options ?? []).map(HackerRankJSONValue.string))
        ]
        switch answer ?? current.answer ?? .options([]) {
        case let .text(value): fields["answer"] = .string(value)
        case let .option(value): fields["answer"] = .int(value)
        case let .options(values): fields["answer"] = .array(values.map(HackerRankJSONValue.int))
        }
        if let customSystemPrompt { fields["custom_system_prompt"] = .string(customSystemPrompt) }
        return .object(fields)
    }
}

/// Metadata writes require strict decoding: malformed optional values must never
/// silently become empty values that overwrite existing remote data.
private nonisolated struct QuestionMetadataSnapshot: Decodable, Sendable {
    let question: Question
    let internalNotes: String?
    let options: [String]?
    let answer: QuestionAnswer?

    enum CodingKeys: String, CodingKey {
        case internalNotes = "internal_notes"
        case options, answer
    }

    init(from decoder: any Decoder) throws {
        question = try Question(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        internalNotes = try container.decodeIfPresent(String.self, forKey: .internalNotes)
        options = try container.decodeIfPresent([String].self, forKey: .options)
        answer = try container.decodeIfPresent(QuestionAnswer.self, forKey: .answer)
    }
}

extension HackerRankClient {
    /// Read current metadata and replace selected fields, preserving required values.
    /// Unselected optional project settings and system prompts are omitted.
    /// A missing required field or invalid prompt fails before the PUT.
    /// Every call writes, even when unchanged. The GET and PUT are separate requests
    /// without a concurrency lock. Writes are not automatically retried.
    /// Returns the server's write result, or nil for a successful empty response.
    @discardableResult
    public func updateQuestionMetadata(
        questionID: String, changes: QuestionMetadataChanges
    ) async throws -> WrittenQuestion? {
        let current = try await fetch(
            QuestionMetadataSnapshot.self, path: "\(Self.apiV3)/questions/\(Self.pathSegment(questionID))"
        )
        let response = try await executeAPI(
            "api_update_question", pathParameters: ["question_id": questionID], body: changes.body(current: current)
        )
        guard let data = response.data, data != .null else { return nil }
        let payload: HackerRankJSONValue = if case let .object(fields) = data, let wrapped = fields["data"] {
            wrapped
        } else {
            data
        }
        if payload == .null { return nil }
        return try Self.makeDecoder().decode(WrittenQuestion.self, from: Self.makeEncoder().encode(payload))
    }
}
