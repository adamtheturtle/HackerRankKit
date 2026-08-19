//
//  TestDetail.swift
//  HackerRankKit
//

import Foundation

/// The richer single-test read (`GET /tests/{id}` → `TestsShow`), carrying fields the list item
/// omits: the candidate login links, the (sensitive) shared access password — best gated behind
/// an explicit reveal in a UI — and the MCQ scoring.
///
/// Every field is optional and decoded resiliently, so a 2xx detail response never fails on a
/// shape that varies between tests.
public nonisolated struct TestDetail: Decodable, Hashable, Sendable {
    /// A short candidate login URL.
    public let shortLoginURL: String?
    /// The public candidate login URL.
    public let publicLoginURL: String?
    /// The shared access password for the test (HackerRank's "master password"; sensitive —
    /// best revealed only on explicit request).
    public let accessPassword: String?
    /// Score awarded for a correct MCQ answer.
    public let mcqCorrectScore: Double?
    /// Score deducted for an incorrect MCQ answer.
    public let mcqIncorrectScore: Double?

    enum CodingKeys: String, CodingKey {
        case shortLoginURL = "short_login_url"
        case publicLoginURL = "public_login_url"
        case accessPassword = "master_password"
        case mcqCorrectScore = "mcq_correct_score"
        case mcqIncorrectScore = "mcq_incorrect_score"
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shortLoginURL = container.loggedDecodeIfPresent(String.self, forKey: .shortLoginURL)
        publicLoginURL = container.loggedDecodeIfPresent(String.self, forKey: .publicLoginURL)
        accessPassword = container.loggedDecodeIfPresent(String.self, forKey: .accessPassword)
        mcqCorrectScore = container.loggedDecodeIfPresent(Double.self, forKey: .mcqCorrectScore)
        mcqIncorrectScore = container.loggedDecodeIfPresent(Double.self, forKey: .mcqIncorrectScore)
    }

    /// Whether the detail adds a login link worth a dedicated section, so a UI can avoid an
    /// empty "Access" group while the fetch is pending or on a test with no links.
    public var hasAccess: Bool {
        shortLoginURL?.isEmpty == false || publicLoginURL?.isEmpty == false || accessPassword?.isEmpty == false
    }

    /// The opt-in fields this model is made of, requested by
    /// ``HackerRankClient/test(id:additionalFields:)`` so a detail read actually returns
    /// what the type promises.
    public static let detailAdditionalFields = [
        "short_login_url",
        "public_login_url",
        "master_password",
        "mcq_correct_score",
        "mcq_incorrect_score"
    ]

    /// Whether MCQ scoring was reported, so that section only shows when present.
    public var hasScoring: Bool {
        mcqCorrectScore != nil || mcqIncorrectScore != nil
    }
}
