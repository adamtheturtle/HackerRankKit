import Foundation

/// Known API question types. Raw strings remain available for future server values.
public nonisolated enum QuestionType: String, Codable, CaseIterable, Hashable, Sendable {
    case code
    case approx
    case mcq
    case multipleMCQ = "multiple_mcq"
    case whiteboard
    case fileUpload = "file_upload"
    case textAnswer = "textAns"
    case fullstack

    /// Whether this question type supports a project AI assistant system prompt.
    public var supportsCustomSystemPrompt: Bool {
        self == .fullstack
    }
}
