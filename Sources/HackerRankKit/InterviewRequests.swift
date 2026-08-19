//
//  InterviewRequests.swift
//  HackerRankKit
//
//  The interview write surface: the instant-pad and scheduled create bodies, and the
//  update body with the options that drive it.
//

import Foundation

/// The candidate invited to an interview (the schema's `CandidateInformation`).
///
/// The API models this as an object, not as a bare email string: a bare string sends the
/// wrong JSON type and loses the candidate's name.
public nonisolated struct InterviewCandidate: Sendable, Equatable, Encodable {
    /// The candidate's email address.
    public let email: String
    /// The candidate's full name, when known.
    public let name: String?

    public init(email: String, name: String? = nil) {
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmedName?.isEmpty == false ? trimmedName : nil
    }
}

/// The wire keys shared by the interview create and update bodies.
enum InterviewWriteCodingKeys: String, CodingKey {
    case title
    case from
    case to
    case notes
    case candidate
    case interviewers
    case replaceInterviewers = "replace_interviewers"
    case resumeURL = "resume_url"
    case resultURL = "result_url"
    case sendEmail = "send_email"
    case metadata
    case interviewTemplateID = "interview_template_id"
    case aiAssistantAvailable = "ai_assistant_available"
}

/// The body sent when creating an instant pad interview.
///
/// An interview created with a title and no scheduled window *is* the instant pad; there
/// is no `quickpad` field in the create schema, and sending one asks the server to accept
/// a property it does not define.
nonisolated struct CreateQuickPadRequest: Encodable {
    let title: String

    enum CodingKeys: String, CodingKey {
        case title
    }
}

/// The body sent when scheduling an interview. Times are ISO-8601 strings; blank optional
/// fields are omitted.
nonisolated struct ScheduleInterviewRequest: Encodable {
    let title: String
    let from: String
    let to: String?
    let candidate: InterviewCandidate?
    let interviewers: [String]?
    let notes: String?

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: InterviewWriteCodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(from, forKey: .from)
        try container.encodeIfPresent(to, forKey: .to)
        try container.encodeIfPresent(candidate, forKey: .candidate)
        try container.encodeIfPresent(interviewers, forKey: .interviewers)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

/// The body sent when updating an interview.
nonisolated struct UpdateInterviewRequest: Encodable {
    let options: InterviewUpdateOptions

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: InterviewWriteCodingKeys.self)
        try container.encodeIfPresent(options.title, forKey: .title)
        try container.encodeIfPresent(options.from, forKey: .from)
        try container.encodeIfPresent(options.to, forKey: .to)
        try container.encodeIfPresent(options.notes, forKey: .notes)
        try container.encodeIfPresent(options.candidate, forKey: .candidate)
        try container.encodeIfPresent(options.resumeURL, forKey: .resumeURL)
        try container.encodeIfPresent(options.resultURL, forKey: .resultURL)
        try container.encodeIfPresent(options.sendEmail, forKey: .sendEmail)
        try container.encodeIfPresent(options.metadata, forKey: .metadata)
        try container.encodeIfPresent(options.interviewTemplateID, forKey: .interviewTemplateID)
        try container.encodeIfPresent(options.aiAssistantAvailable, forKey: .aiAssistantAvailable)
        guard let interviewers = options.interviewers else { return }

        // The server keeps the existing list unless it is told to replace it, so supplying
        // interviewers without this flag returned success and changed nothing. An explicit
        // `replaceInterviewers` still wins, for a caller who means to append.
        try container.encode(interviewers, forKey: .interviewers)
        try container.encode(options.replaceInterviewers ?? true, forKey: .replaceInterviewers)
    }
}

/// Optional fields for updating an interview.
///
/// The text fields and the interviewer list distinguish "not supplied" (`nil`, leave
/// unchanged) from "supplied as empty" (clear it), so an existing title, note, or
/// interviewer list can actually be removed.
public nonisolated struct InterviewUpdateOptions: Sendable, Equatable {
    /// The interview's title. An explicit empty string clears it.
    public let title: String?
    /// ISO-8601 scheduled start.
    public let from: String?
    /// ISO-8601 scheduled end.
    public let to: String?
    /// The candidate being interviewed.
    public let candidate: InterviewCandidate?
    /// The interviewers to invite. An explicit empty array clears the list.
    public let interviewers: [String]?
    /// Whether the supplied list replaces the existing interviewers. Defaults to `true`
    /// whenever ``interviewers`` is supplied.
    public let replaceInterviewers: Bool?
    /// Notes for the interviewer. An explicit empty string clears them.
    public let notes: String?
    /// URL of the candidate's résumé.
    public let resumeURL: String?
    /// Webhook URL the interview result is posted to.
    public let resultURL: String?
    /// Whether to send or resend the invitation email.
    public let sendEmail: Bool?
    /// Free-form metadata attached to the interview.
    public let metadata: [String: HackerRankJSONValue]?
    /// Identifier of the interview template to apply.
    public let interviewTemplateID: Int?
    /// Whether the AI assistant is available during the interview.
    public let aiAssistantAvailable: Bool?

    public init(
        title: String? = nil,
        from: String? = nil,
        to: String? = nil,
        candidate: InterviewCandidate? = nil,
        interviewers: [String]? = nil,
        replaceInterviewers: Bool? = nil,
        notes: String? = nil,
        resumeURL: String? = nil,
        resultURL: String? = nil,
        sendEmail: Bool? = nil,
        metadata: [String: HackerRankJSONValue]? = nil,
        interviewTemplateID: Int? = nil,
        aiAssistantAvailable: Bool? = nil
    ) {
        // nil means "leave unchanged"; an explicitly supplied empty value means "clear".
        self.title = title.map(Self.trimmed)
        self.from = Self.nonBlank(from)
        self.to = Self.nonBlank(to)
        self.candidate = candidate
        self.interviewers = interviewers.map { $0.compactMap(Self.nonBlank) }
        self.replaceInterviewers = replaceInterviewers
        self.notes = notes.map(Self.trimmed)
        self.resumeURL = Self.nonBlank(resumeURL)
        self.resultURL = Self.nonBlank(resultURL)
        self.sendEmail = sendEmail
        self.metadata = metadata?.isEmpty == false ? metadata : nil
        self.interviewTemplateID = interviewTemplateID
        self.aiAssistantAvailable = aiAssistantAvailable
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The interview echoed back by a successful create. All-optional so a 2xx never fails
/// to decode on an unexpected shape; the URL lets a client open the new pad.
public nonisolated struct CreatedInterview: Decodable, Sendable {
    public let id: String?
    public let url: String?
    public let status: String?
}
