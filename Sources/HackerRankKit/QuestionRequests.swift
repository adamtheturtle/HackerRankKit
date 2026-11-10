import Foundation

nonisolated enum QuestionPromptValidation {
    static func validate(type: String?, prompt: String?) throws {
        guard let prompt else { return }
        if prompt.unicodeScalars.count > 15000 {
            throw EncodingError.invalidValue(prompt, .init(
                codingPath: [], debugDescription: "Custom system prompt must be at most 15,000 characters."
            ))
        }
        if let type, let known = QuestionType(rawValue: type.trimmingCharacters(in: .whitespacesAndNewlines)),
           !known.supportsCustomSystemPrompt {
            throw EncodingError.invalidValue(type, .init(
                codingPath: [], debugDescription: "Custom system prompt is not supported for question type \(type)."
            ))
        }
    }

    static func validate(body: HackerRankJSONValue?) throws {
        guard case let .object(fields) = body, let value = fields["custom_system_prompt"],
              value != .null else { return }
        guard case let .string(prompt) = value else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: [], debugDescription: "Custom system prompt must be a string or null."
            ))
        }
        let type: String? = if case let .string(value) = fields["type"] {
            value
        } else {
            nil
        }
        try validate(type: type, prompt: prompt)
    }
}

extension HackerRankClient {
    nonisolated static func questionWritePath(method: String, path: String) -> String {
        let root = "\(apiV3)/questions"
        guard ["POST", "PUT"].contains(method), path == root || path.hasPrefix(root + "/") else { return path }
        var canonical = path
        while canonical.last == "/" {
            canonical.removeLast()
        }
        return canonical + "/"
    }
}
