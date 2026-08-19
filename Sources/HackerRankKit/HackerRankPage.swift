//
//  HackerRankPage.swift
//  HackerRankKit
//

import Foundation
import PaginatedRESTClient

/// The HackerRank for Work list-response envelope: `{ "data": [...], "next": "<url>", ... }`.
///
/// HackerRank paginates by `offset`/`limit` and returns an absolute `next` URL for the
/// following page. `total` is deliberately reported as `nil` so the transport uses its
/// sequential `next`-walk rather than its page-number fast path, which assumes
/// `?page=N` URLs HackerRank does not honour. Pagination metadata other than `data`
/// and `next` is ignored.
///
/// `data` is decoded **leniently**: any single record that fails to decode is dropped
/// rather than failing the whole page, so one malformed item on a live account never breaks
/// the entire list. The models are already resilient (every non-identifying field optional);
/// this is the page-level backstop.
/// A value that may or may not carry an identity, letting ``HackerRankPage/identity(of:)``
/// distinguish an item whose optional id is absent from one that has a real id. Without it,
/// every id-less row would share the identity "`nil` wrapped in `AnyHashable`" and the
/// transport's de-duplication would collapse them into a single row.
private nonisolated protocol OptionalIdentity {
    nonisolated var isAbsent: Bool { get }
}

extension Optional: OptionalIdentity {
    fileprivate nonisolated var isAbsent: Bool {
        self == nil
    }
}

public nonisolated struct HackerRankPage<Item: Decodable & Sendable & Identifiable>: PagedResponse {
    public let data: [Item]
    public let next: String?
    /// The collection's total size from the envelope's `total` field, when present. Kept separate
    /// from the protocol's `total` (below, deliberately `nil`); used to fan out a bounded
    /// collection's remaining pages in parallel by offset.
    public let totalCount: Int?

    enum CodingKeys: String, CodingKey {
        case data
        case next
        case total
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lenient = try container.decode([LenientElement<Item>].self, forKey: .data)
        data = lenient.compactMap(\.value)
        next = try container.decodeIfPresent(String.self, forKey: .next)
        totalCount = Self.flexibleTotal(container)
    }

    /// The envelope's `total`, which the v3 list responses document as a **string** (`"13"`)
    /// while some endpoints send a number. Reading only `Int` left `totalCount` nil for a
    /// conforming response, which also stopped `allUsers` fanning out past page one.
    private static func flexibleTotal(_ container: KeyedDecodingContainer<CodingKeys>) -> Int? {
        if let number = try? container.decodeIfPresent(Int.self, forKey: .total) { return number }
        guard let text = try? container.decodeIfPresent(String.self, forKey: .total) else { return nil }

        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public var pageItems: [Item] {
        data
    }

    public var nextPage: String? {
        next
    }

    public var total: Int? {
        nil
    }

    /// The page size the client asks these endpoints for — the API's documented maximum,
    /// which is ``HackerRankClient/pageSize``. Every first-page request this client builds
    /// sends `limit=\(HackerRankClient.pageSize)`, so the two are the same number by
    /// definition and are sourced from one constant rather than restated here.
    ///
    /// The transport derives its parallel page count from this rather than from the first
    /// response's item count, which the lenient decoder above can leave short.
    public static var pageSize: Int {
        HackerRankClient.pageSize
    }

    /// Each item's own `id`, so pages stitched by the transport de-duplicate rather than
    /// dropping to the sequential walk. An item whose id is optional and absent has no stable
    /// identity, so it reports `nil` instead of colliding with every other id-less row.
    public static func identity(of item: Item) -> AnyHashable? {
        if let optional = item.id as? any OptionalIdentity, optional.isAbsent { return nil }

        return item.id
    }
}
