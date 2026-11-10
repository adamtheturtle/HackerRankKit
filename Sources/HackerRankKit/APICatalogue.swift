import Foundation

/// One path or query parameter from the published HackerRank contract.
public nonisolated struct HackerRankAPIParameter: Codable, Hashable, Sendable {
    public let name: String
    public let location: String
    public let type: String
    public let required: Bool
    public let description: String
    public let items: HackerRankJSONValue?
    public let enumeration: HackerRankJSONValue?
    public let defaultValue: HackerRankJSONValue?

    enum CodingKeys: String, CodingKey {
        case name, location, type, required, description, items
        case enumeration = "enum", defaultValue = "default"
    }
}

/// One documented operation, including its request schema and provisioning namespace.
public nonisolated struct HackerRankAPIOperation: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let method: String
    public let path: String
    public let group: String
    public let summary: String
    public let description: String
    public let scim: Bool
    public let parameters: [HackerRankAPIParameter]
    public let bodySchema: HackerRankJSONValue?
    public let bodyRequired: Bool
    public let fixedQuery: [String: String]
    public var isWrite: Bool {
        method != "GET"
    }
}

/// The complete operation catalogue and the schemas referenced by request bodies.
public nonisolated struct HackerRankAPICatalogue: Codable, Sendable {
    public let operations: [HackerRankAPIOperation]
    public let definitions: [String: HackerRankJSONValue]
}

/// A complete operation result, including empty and HTTP 202 responses.
public nonisolated struct HackerRankAPIResponse: Codable, Sendable {
    public let status: Int
    public let headers: [String: String]
    public let data: HackerRankJSONValue?
}

extension HackerRankClient {
    /// Loads the bundled catalogue generated from HackerRank's official specification.
    public nonisolated static func apiCatalogue() throws -> HackerRankAPICatalogue {
        guard let location = Bundle.module.url(forResource: "api_operations", withExtension: "json") else {
            throw HackerRankError.decode("Missing API operation catalogue")
        }
        return try JSONDecoder().decode(HackerRankAPICatalogue.self, from: Data(contentsOf: location))
    }

    /// Executes a documented operation with its complete query and JSON body surface.
    /// SCIM requires its own credential and uses scimBaseURL. No write is automatically retried.
    public func executeAPI(_ operationID: String, pathParameters: [String: String] = [:],
                           query: [URLQueryItem] = [], body: HackerRankJSONValue? = nil,
                           scimToken: String? = nil) async throws -> HackerRankAPIResponse {
        guard let operation = try Self.apiCatalogue().operations.first(where: { $0.id == operationID }) else {
            throw HackerRankError.http(0, "Unknown API operation")
        }
        var query = query
        for (key, value) in operation.fixedQuery where !query.contains(where: { $0.name == key }) {
            query.append(URLQueryItem(name: key, value: value))
        }
        var path = operation.path
        for parameter in operation.parameters where parameter.location == "path" {
            guard let value = pathParameters[parameter.name], !value.isEmpty else {
                throw HackerRankError.http(0, "Missing path parameter: \(parameter.name)")
            }
            path = path.replacingOccurrences(of: "{\(parameter.name)}", with: Self.pathSegment(value))
        }
        for parameter in operation.parameters where parameter.location == "query" && parameter.required {
            guard query.contains(where: { $0.name == parameter.name && $0.value != nil }) else {
                throw HackerRankError.http(0, "Missing query parameter: \(parameter.name)")
            }
        }
        guard !operation.bodyRequired || body != nil else {
            throw HackerRankError.http(0, "This operation requires a JSON body")
        }
        path = Self.questionWritePath(method: operation.method, path: path)
        if ["POST", "PUT"].contains(operation.method),
           path.hasPrefix("\(Self.apiV3)/questions/") {
            try QuestionPromptValidation.validate(body: body)
        }
        let credential: String
        if operation.scim {
            guard let scimToken, !scimToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HackerRankError.http(0, "Configure a separate SCIM token for this operation")
            }
            credential = scimToken
        } else {
            credential = token
        }
        guard !credential.isEmpty else { throw HackerRankError.missingAPIKey }

        var request = URLRequest(url: try url(path: path, query: query, base: operation.scim ? scimBaseURL : nil))
        request.httpMethod = operation.method
        request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try Self.makeEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
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
        guard (200 ..< 300).contains(http.statusCode) else {
            throw HackerRankError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let payload: HackerRankJSONValue?
        do {
            payload = data.isEmpty ? nil : try Self.makeDecoder().decode(HackerRankJSONValue.self, from: data)
        } catch {
            throw HackerRankError.decode(String(describing: error))
        }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, field in
            guard let key = field.key as? String, let value = field.value as? String else { return }
            result[key] = value
        }
        return HackerRankAPIResponse(status: http.statusCode, headers: headers, data: payload)
    }
}
