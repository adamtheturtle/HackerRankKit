import Foundation

extension HackerRankClient {
    /// Reads a v3 resource while preserving all documented and additional JSON fields.
    /// Useful for integrations which need the complete response rather than a display model.
    /// Paths must be percent-encoded and relative to the configured origin, under /x/api/v3/.
    /// A continuation URL is validated against the configured origin before authentication.
    public func resourceJSON(path: String, after cursor: String? = nil,
                             query: [URLQueryItem] = []) async throws -> HackerRankJSONValue {
        guard path.hasPrefix("\(Self.apiV3)/"), !path.contains("?"), !path.contains("#"),
              !path.split(separator: "/").contains("..") else {
            throw HackerRankError.http(0, "Expected a v3 resource path without query or fragment")
        }
        let target: URL
        if let cursor {
            guard let continuation = cursorURL(cursor) else {
                throw HackerRankError.http(0, "Invalid next-page URL")
            }
            target = continuation
        } else {
            target = try url(path: path, query: query)
        }
        return try await rest.performWithRetry(HackerRankJSONValue.self, request: try authorizedGET(target))
    }
}
