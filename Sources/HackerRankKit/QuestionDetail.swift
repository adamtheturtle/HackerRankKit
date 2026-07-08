//
//  QuestionDetail.swift
//  HackerRankKit
//

import Foundation

/// The richer single-question read (`GET /questions/{id}` → `QuestionShow`), carrying fields the
/// list item omits: the MCQ `options` and the correct `answer` (both **sensitive** — the answer
/// is best gated behind an explicit reveal in a UI) and the author's `internal_notes`.
///
/// Every field is optional and decoded resiliently, so a 2xx detail response never fails on a
/// shape that varies between question types (a coding question carries no options/answer).
public nonisolated struct QuestionDetail: Decodable, Hashable, Sendable {
    /// The MCQ answer choices, in order.
    public let options: [String]
    /// The correct answer (sensitive — best revealed only on explicit request).
    public let answer: String?
    /// The author's private notes about the question.
    public let internalNotes: String?

    enum CodingKeys: String, CodingKey {
        case options
        case answer
        case internalNotes = "internal_notes"
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        options = (container.loggedDecodeIfPresent([String].self, forKey: .options)) ?? []
        answer = container.loggedDecodeIfPresent(String.self, forKey: .answer)
        internalNotes = container.loggedDecodeIfPresent(String.self, forKey: .internalNotes)
    }

    /// Whether the detail adds anything worth showing over the list row, so a UI can avoid
    /// rendering empty sections while the fetch is pending or on a question type with no extras.
    public var hasContent: Bool {
        !options.isEmpty || answer?.isEmpty == false || internalNotes?.isEmpty == false
    }
}
