//
//  InterviewDetail.swift
//  HackerRankKit
//

import Foundation

/// The richer single-interview read (`GET /interviews/{id}` → `InterviewShow`), carrying the
/// fields the list item omits: the scheduled window, the interviewers, the owning user, the
/// candidate, and the links to the résumé and result. Every field is optional so a 2xx detail
/// response never fails to decode on a shape that differs between interview kinds. The
/// collaborative pad's source code is **not** exposed by the API, so it is not modelled here.
public nonisolated struct InterviewDetail: Codable, Hashable, Sendable {
    /// ISO-8601 scheduled start.
    public let scheduledFrom: String?
    /// ISO-8601 scheduled end.
    public let scheduledTo: String?
    /// URL of the candidate's résumé, if attached.
    public let resumeURL: String?
    /// URL of the interview's result/report.
    public let resultURL: String?
    /// The people conducting the interview.
    public let interviewers: [InterviewPerson]
    /// The interview's owner/creator.
    public let user: InterviewPerson?
    /// The candidate being interviewed.
    public let candidate: InterviewPerson?

    enum CodingKeys: String, CodingKey {
        case scheduledFrom = "from"
        case scheduledTo = "to"
        case resumeURL = "resume_url"
        case resultURL = "result_url"
        case interviewers
        case user
        case candidate
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheduledFrom = container.loggedDecodeIfPresent(String.self, forKey: .scheduledFrom)
        scheduledTo = container.loggedDecodeIfPresent(String.self, forKey: .scheduledTo)
        resumeURL = container.loggedDecodeIfPresent(String.self, forKey: .resumeURL)
        resultURL = container.loggedDecodeIfPresent(String.self, forKey: .resultURL)
        interviewers = (container.loggedDecodeIfPresent([InterviewPerson].self, forKey: .interviewers)) ?? []
        user = container.loggedDecodeIfPresent(InterviewPerson.self, forKey: .user)
        candidate = container.loggedDecodeIfPresent(InterviewPerson.self, forKey: .candidate)
    }

    /// Whether the detail carries any people worth a dedicated section, so a UI can avoid an
    /// empty "People" group when the detail response adds nothing over the list row.
    public var hasPeople: Bool {
        !interviewers.isEmpty || user != nil || candidate != nil
    }
}

/// A person attached to an interview — an interviewer, the owner, or the candidate. The API
/// returns these either as a bare email/name string or as an object, so this decodes both
/// shapes rather than dropping the field when it differs.
public nonisolated struct InterviewPerson: Codable, Hashable, Sendable {
    public let email: String?
    public let firstName: String?
    public let lastName: String?
    public let name: String?

    enum CodingKeys: String, CodingKey {
        case email
        case firstName = "firstname"
        case lastName = "lastname"
        case name
    }

    public init(email: String? = nil, firstName: String? = nil, lastName: String? = nil, name: String? = nil) {
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.name = name
    }

    public nonisolated init(from decoder: any Decoder) throws {
        // A bare string (an email address or a display name) is a valid shape for entries in the
        // interviewers array, so decode that before falling back to the keyed object.
        if let single = try? decoder.singleValueContainer(), let value = try? single.decode(String.self) {
            let isEmail = value.contains("@")
            self.init(email: isEmail ? value : nil, name: isEmail ? nil : value)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            email: container.loggedDecodeIfPresent(String.self, forKey: .email),
            firstName: container.loggedDecodeIfPresent(String.self, forKey: .firstName),
            lastName: container.loggedDecodeIfPresent(String.self, forKey: .lastName),
            name: container.loggedDecodeIfPresent(String.self, forKey: .name)
        )
    }

    /// A human-readable label: an explicit name, else first + last, else the email, else "Unknown".
    public var displayName: String {
        if let name, !name.isEmpty { return name }
        let full = [firstName, lastName]
            .compactMap(\.self)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        return email ?? "Unknown"
    }
}

/// The interview's conversation transcript (`GET /interviews/{id}/transcript` →
/// `InterviewTranscriptShow`): the spoken/typed messages only. The collaborative pad's source
/// code is not part of the transcript.
public nonisolated struct InterviewTranscript: Codable, Hashable, Sendable {
    public let messages: [InterviewMessage]

    enum CodingKeys: String, CodingKey {
        case messages
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messages = (container.loggedDecodeIfPresent([InterviewMessage].self, forKey: .messages)) ?? []
    }
}

/// One line of an interview transcript. Top-level (not nested in `InterviewTranscript`)
/// so its `CodingKeys` don't exceed a strict type-nesting limit.
public nonisolated struct InterviewMessage: Codable, Hashable, Identifiable, Sendable {
    public let messageID: String?
    public let author: String?
    public let email: String?
    /// Whether the author is the candidate (vs an interviewer), for styling.
    public let candidate: Bool?
    /// Unix epoch seconds the message was sent.
    public let timestamp: Int?
    public let text: String?

    /// Stable identity for `ForEach`: the server's `messageId` when present, otherwise a
    /// composite of the fields that's good enough to keep rows distinct.
    public var id: String {
        messageID ?? "\(author ?? "")-\(timestamp ?? 0)-\(text?.count ?? 0)"
    }

    enum CodingKeys: String, CodingKey {
        case messageID = "messageId"
        case author
        case email
        case candidate
        case timestamp
        case text
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageID = container.loggedDecodeIfPresent(String.self, forKey: .messageID)
        author = container.loggedDecodeIfPresent(String.self, forKey: .author)
        email = container.loggedDecodeIfPresent(String.self, forKey: .email)
        candidate = container.loggedDecodeIfPresent(Bool.self, forKey: .candidate)
        timestamp = container.loggedDecodeIfPresent(Int.self, forKey: .timestamp)
        text = container.loggedDecodeIfPresent(String.self, forKey: .text)
    }
}
