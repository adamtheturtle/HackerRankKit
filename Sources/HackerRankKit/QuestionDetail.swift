//
//  QuestionDetail.swift
//  HackerRankKit
//

import Foundation

/// The correct answer to a multiple-choice question.
///
/// Preserve the API representation: a string, a single integer, or an integer array.
/// Strings are never interpreted as option indices.
public nonisolated enum QuestionAnswer: Codable, Hashable, Sendable {
    /// The exact answer text returned by the API, including numeric-looking strings.
    case text(String)
    /// The single correct option, as a one-based index into the question's options.
    case option(Int)
    /// The correct options, as one-based indices, for a multiple-answer question.
    case options([Int])

    /// Numeric answers as one-based indices. Text answers have no inferred indices.
    public var indices: [Int] {
        switch self {
        case .text: []
        case let .option(index): [index]
        case let .options(indices): indices
        }
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }
        if let index = try? container.decode(Int.self) {
            self = .option(index)
            return
        }

        self = .options(try container.decode([Int].self))
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(text): try container.encode(text)
        case let .option(index): try container.encode(index)
        case let .options(indices): try container.encode(indices)
        }
    }
}

/// The single-question read (`GET /questions/{id}` → `QuestionShow`).
///
/// `QuestionShow` is the same resource as the list row plus the MCQ `options` and `answer`
/// and the author's `internal_notes`, so the whole record is carried here: a detail refresh
/// can replace a stale list row rather than only annotating one. The answer and the
/// internal notes are **sensitive** — the answer is best gated behind an explicit reveal.
public nonisolated struct QuestionDetail: Decodable, Hashable, Sendable {
    /// The question resource itself, exactly as the list returns it.
    public let question: Question
    /// The MCQ answer choices, in order.
    public let options: [String]
    /// The correct answer (sensitive — best revealed only on explicit request).
    public let answer: QuestionAnswer?
    /// The author's private notes about the question.
    public let internalNotes: String?

    enum CodingKeys: String, CodingKey {
        case options
        case answer
        case internalNotes = "internal_notes"
    }

    public init(
        question: Question,
        options: [String] = [],
        answer: QuestionAnswer? = nil,
        internalNotes: String? = nil
    ) {
        self.question = question
        self.options = options
        self.answer = answer
        self.internalNotes = internalNotes
    }

    public nonisolated init(from decoder: any Decoder) throws {
        question = try Question(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        options = (container.loggedDecodeIfPresent([String].self, forKey: .options)) ?? []
        answer = container.loggedDecodeIfPresent(QuestionAnswer.self, forKey: .answer)
        internalNotes = container.loggedDecodeIfPresent(String.self, forKey: .internalNotes)
    }

    /// Whether the detail adds anything worth showing over the list row, so a UI can avoid
    /// rendering empty sections while the fetch is pending or on a question type with no extras.
    public var hasContent: Bool {
        !options.isEmpty || answer != nil || internalNotes?.isEmpty == false
    }
}
