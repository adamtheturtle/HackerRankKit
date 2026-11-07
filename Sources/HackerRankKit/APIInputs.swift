import Foundation

extension HackerRankAPICatalogue {
    /// A self-contained JSON schema for the complete path/query/body input surface.
    public nonisolated func inputSchema(for operation: HackerRankAPIOperation) -> HackerRankJSONValue {
        var properties: [String: HackerRankJSONValue] = [:]
        var required: [HackerRankJSONValue] = []
        for location in ["path", "query"] {
            let parameters = operation.parameters.filter { $0.location == location }
            var fields: [String: HackerRankJSONValue] = [:]
            for parameter in parameters {
                var field: [String: HackerRankJSONValue] = [
                    "type": parameterType(parameter, location: location),
                    "description": .string(parameter.description)
                ]
                if let items = parameter.items, items != .null { field["items"] = resolve(items, seen: []) }
                if let enumeration = parameter.enumeration, enumeration != .null { field["enum"] = enumeration }
                if let value = parameter.defaultValue, value != .null { field["default"] = value }
                fields[parameter.name] = .object(field)
            }
            let mandatory = parameters.filter(\.required).map { HackerRankJSONValue.string($0.name) }
            properties[location] = .object([
                "type": .string("object"), "properties": .object(fields), "required": .array(mandatory),
                "additionalProperties": .bool(location == "query")
            ])
            if !mandatory.isEmpty { required.append(.string(location)) }
        }
        if let body = operation.bodySchema, body != .null {
            properties["body"] = resolve(body, seen: [])
            if operation.bodyRequired { required.append(.string("body")) }
        }
        return .object([
            "type": .string("object"), "properties": .object(properties),
            "required": .array(required), "additionalProperties": .bool(false)
        ])
    }

    private nonisolated func parameterType(_ parameter: HackerRankAPIParameter, location: String) -> HackerRankJSONValue {
        location == "path" ? .array([.string("string"), .string("integer")]) : .string(parameter.type)
    }

    private nonisolated func resolve(_ value: HackerRankJSONValue, seen: Set<String>) -> HackerRankJSONValue {
        switch value {
        case let .array(values): return .array(values.map { resolve($0, seen: seen) })
        case let .object(fields):
            if case let .string(reference)? = fields["$ref"], reference.hasPrefix("#/definitions/") {
                let name = String(reference.dropFirst("#/definitions/".count))
                guard !seen.contains(name), let definition = definitions[name] else { return .object([:]) }
                return resolve(definition, seen: seen.union([name]))
            }
            return .object(fields.mapValues { resolve($0, seen: seen) })
        default: return value
        }
    }
}

/// Inputs shared by API explorers, command integrations and MCP providers.
public nonisolated struct HackerRankAPIInputs: Sendable {
    public let pathParameters: [String: String]
    public let query: [URLQueryItem]
    public let body: HackerRankJSONValue?

    public init(value: HackerRankJSONValue) throws {
        guard case let .object(fields) = value else { throw HackerRankError.http(0, "Expected an input object") }
        let path = try Self.object(fields["path"])
        var resolved: [String: String] = [:]
        for (key, value) in path {
            switch value {
            case let .string(text): resolved[key] = text
            case let .int(number): resolved[key] = String(number)
            default: throw HackerRankError.http(0, "Path parameters must be strings or integers")
            }
        }
        pathParameters = resolved
        let parameters = try Self.object(fields["query"])
        query = try parameters.sorted(by: { $0.key < $1.key }).compactMap { key, value in
            if value == .null { return nil }
            return try URLQueryItem(name: key, value: Self.queryText(value))
        }
        body = fields["body"]
    }

    private static func object(_ value: HackerRankJSONValue?) throws -> [String: HackerRankJSONValue] {
        guard let value else { return [:] }
        guard case let .object(fields) = value else { throw HackerRankError.http(0, "path and query must be objects") }
        return fields
    }

    private static func queryText(_ value: HackerRankJSONValue) throws -> String {
        switch value {
        case let .string(text): return text
        case let .int(number): return String(number)
        case let .double(number): return String(number)
        case let .bool(flag): return String(flag)
        case let .array(values): return try values.map { try queryText($0) }.joined(separator: ",")
        default: throw HackerRankError.http(0, "Query values must be scalars or arrays of scalars")
        }
    }
}
