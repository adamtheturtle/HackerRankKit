//
//  Interview.swift
//  HackerRankKit
//

import Foundation

/// A HackerRank for Work interview.
///
/// Only the fields a read-only UI typically needs are modelled; `Decodable` ignores any
/// other keys, so this decodes live responses without failing on unmodelled fields.
public nonisolated struct Interview: Codable, Hashable, Identifiable, Sendable {
    /// The unique identifier of the interview.
    public let id: String
    /// The lifecycle status of the interview.
    public let status: String
    /// The interview's web URL.
    public let url: String
    /// The interview's display title, if any.
    public let title: String?
    /// Reviewer feedback, if any.
    public let feedback: String?
    /// A thumbs-up rating, if any.
    public let thumbsUp: Int?
    /// Free-text notes.
    public let notes: String?
    /// ISO-8601 creation timestamp.
    public let createdAt: String?
    /// ISO-8601 last-updated timestamp.
    public let updatedAt: String?
    /// ISO-8601 time the interview ended.
    public let endedAt: String?
    /// Identifier of the interview template used.
    public let interviewTemplateID: Int?
    /// URL of the interview's report, if any.
    public let reportURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case url
        case title
        case feedback
        case thumbsUp = "thumbs_up"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case endedAt = "ended_at"
        case interviewTemplateID = "interview_template_id"
        case reportURL = "report_url"
    }

    public init(
        id: String,
        status: String,
        url: String,
        title: String? = nil,
        feedback: String? = nil,
        thumbsUp: Int? = nil,
        notes: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        endedAt: String? = nil,
        interviewTemplateID: Int? = nil,
        reportURL: String? = nil
    ) {
        self.id = id
        self.status = status
        self.url = url
        self.title = title
        self.feedback = feedback
        self.thumbsUp = thumbsUp
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.endedAt = endedAt
        self.interviewTemplateID = interviewTemplateID
        self.reportURL = reportURL
    }
}

extension Interview {
    /// Decodes resiliently. `status` and `url` are required in the schema but can be absent or
    /// null on live records (e.g. a freshly scheduled interview with no URL yet); the page
    /// decoder drops any element that throws, so without this those interviews silently vanish
    /// from the list. They default to "" so the record still appears. Only `id` is truly
    /// required — an interview with no identity can't be shown.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = (container.loggedDecodeIfPresent(String.self, forKey: .status)) ?? ""
        url = (container.loggedDecodeIfPresent(String.self, forKey: .url)) ?? ""
        title = container.loggedDecodeIfPresent(String.self, forKey: .title)
        feedback = container.loggedDecodeIfPresent(String.self, forKey: .feedback)
        thumbsUp = container.loggedDecodeIfPresent(Int.self, forKey: .thumbsUp)
        notes = container.loggedDecodeIfPresent(String.self, forKey: .notes)
        createdAt = container.loggedDecodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = container.loggedDecodeIfPresent(String.self, forKey: .updatedAt)
        endedAt = container.loggedDecodeIfPresent(String.self, forKey: .endedAt)
        interviewTemplateID = container.loggedDecodeIfPresent(Int.self, forKey: .interviewTemplateID)
        reportURL = container.loggedDecodeIfPresent(String.self, forKey: .reportURL)
    }
}
