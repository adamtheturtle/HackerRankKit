//
//  CodeStubs.swift
//  HackerRankKit
//
//  The code-stub surface of the question endpoints: the custom templates a caller
//  uploads, the signature metadata that drives generation, and the generated templates
//  the API returns.
//

import Foundation

/// One language's custom code stub for a coding question.
///
/// The API models a template as a head, a required body, and a tail — the head and tail are
/// the boilerplate a candidate does not edit, the body is what they see and complete. A
/// single `code` blob could not express that split.
public nonisolated struct QuestionCodeStub: Sendable, Equatable, Encodable {
    /// The language the template is written in.
    public let language: String
    /// Boilerplate placed above the candidate's code.
    public let head: String?
    /// The template the candidate edits. Required by the API.
    public let body: String
    /// Boilerplate placed below the candidate's code.
    public let tail: String?

    public init(language: String, body: String, head: String? = nil, tail: String? = nil) {
        self.language = language.trimmingCharacters(in: .whitespacesAndNewlines)
        self.body = body
        self.head = head
        self.tail = tail
    }
}

/// The body sent when replacing a question's custom code stubs.
nonisolated struct CustomCodeStubsRequest: Encodable {
    let stubs: [QuestionCodeStub]

    enum CodingKeys: String, CodingKey {
        case stubs = "templates"
    }
}

/// The signature metadata HackerRank generates code stubs from.
///
/// Every field is one string, exactly as the endpoint documents it: the parameter list is a
/// single signature such as `INTEGER param1 STRING param2`, and the languages are joined
/// into one comma-separated value. Sending structured JSON here meant the generator
/// received none of it.
public nonisolated struct CodeStubGenerationOptions: Sendable, Equatable {
    /// The question type driving generation — `code` or `approx`.
    public let type: String?
    /// The name of the function to generate.
    public let functionName: String?
    /// The parameter list, e.g. `INTEGER param1 STRING param2`.
    public let functionParams: String?
    /// The function's return type, e.g. `INTEGER`.
    public let functionReturn: String?
    /// The languages to generate templates for.
    public let allowedLanguages: [String]?

    public init(
        type: String? = nil,
        functionName: String? = nil,
        functionParams: String? = nil,
        functionReturn: String? = nil,
        allowedLanguages: [String]? = nil
    ) {
        self.type = Self.nonBlank(type)
        self.functionName = Self.nonBlank(functionName)
        self.functionParams = Self.nonBlank(functionParams)
        self.functionReturn = Self.nonBlank(functionReturn)
        let cleaned = allowedLanguages?.compactMap(Self.nonBlank)
        self.allowedLanguages = cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func nonBlank(_ value: String?) -> String? {
        let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }
}

/// The body sent when asking HackerRank to generate code stubs for a coding question.
nonisolated struct GenerateCodeStubsRequest: Encodable {
    let options: CodeStubGenerationOptions

    /// The generate endpoint is the one place the API uses camelCase keys.
    enum CodingKeys: String, CodingKey {
        case type
        case functionName
        case functionParams
        case functionReturn
        case allowedLanguages
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(options.type, forKey: .type)
        try container.encodeIfPresent(options.functionName, forKey: .functionName)
        try container.encodeIfPresent(options.functionParams, forKey: .functionParams)
        try container.encodeIfPresent(options.functionReturn, forKey: .functionReturn)
        try container.encodeIfPresent(options.allowedLanguages?.joined(separator: ","), forKey: .allowedLanguages)
    }
}

/// One generated template: the head and tail boilerplate around the body a candidate edits.
public nonisolated struct GeneratedCodeTemplate: Hashable, Sendable, Identifiable {
    /// The language the template was generated for.
    public let language: String
    /// Boilerplate placed above the candidate's code.
    public let head: String?
    /// The template the candidate edits.
    public let body: String?
    /// Boilerplate placed below the candidate's code.
    public let tail: String?

    public var id: String {
        language
    }

    public init(language: String, head: String? = nil, body: String? = nil, tail: String? = nil) {
        self.language = language
        self.head = head
        self.body = body
        self.tail = tail
    }
}

/// What `PUT /questions/{id}/generate` actually returns: the signature it generated from
/// and one template per requested language.
///
/// The API names the template keys after the language (`c_template_head`, `c_template`,
/// `c_template_tail`), so they are collected into ``templates`` rather than enumerated.
public nonisolated struct GeneratedCodeStubs: Decodable, Hashable, Sendable {
    /// The name of the generated function.
    public let functionName: String?
    /// The parameter list the templates were generated from.
    public let functionParams: String?
    /// The generated function's return type.
    public let functionReturn: String?
    /// The languages templates were generated for, as the API returned them.
    public let allowedLanguages: String?
    /// The kind of template that was generated.
    public let templateType: String?
    /// The generated templates, one per language, sorted by language.
    public let templates: [GeneratedCodeTemplate]

    public init(
        functionName: String? = nil,
        functionParams: String? = nil,
        functionReturn: String? = nil,
        allowedLanguages: String? = nil,
        templateType: String? = nil,
        templates: [GeneratedCodeTemplate] = []
    ) {
        self.functionName = functionName
        self.functionParams = functionParams
        self.functionReturn = functionReturn
        self.allowedLanguages = allowedLanguages
        self.templateType = templateType
        self.templates = templates
    }

    /// A key of any name, so the per-language template keys can be read without knowing
    /// which languages were asked for.
    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? {
            nil
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        func string(_ name: String) -> String? {
            guard let key = AnyKey(stringValue: name) else { return nil }

            return container.loggedDecodeIfPresent(String.self, forKey: key)
        }
        functionName = string("functionName")
        functionParams = string("functionParams")
        functionReturn = string("functionReturn")
        allowedLanguages = string("allowedLanguages")
        templateType = string("templateType")

        var heads: [String: String] = [:]
        var bodies: [String: String] = [:]
        var tails: [String: String] = [:]
        for key in container.allKeys {
            guard let (language, part) = Self.templatePart(of: key.stringValue),
                  let value = container.loggedDecodeIfPresent(String.self, forKey: key) else { continue }

            switch part {
            case .head: heads[language] = value
            case .body: bodies[language] = value
            case .tail: tails[language] = value
            }
        }
        templates = Set(heads.keys).union(bodies.keys).union(tails.keys).sorted().map { language in
            GeneratedCodeTemplate(
                language: language, head: heads[language], body: bodies[language], tail: tails[language]
            )
        }
    }

    private enum TemplatePart { case head, body, tail }

    /// Splits a response key such as `clojure_template_head` into its language and part,
    /// or `nil` when the key is not a template.
    private static func templatePart(of key: String) -> (String, TemplatePart)? {
        for (suffix, part) in [("_template_head", TemplatePart.head), ("_template_tail", .tail), ("_template", .body)]
            where key.hasSuffix(suffix) {
            let language = String(key.dropLast(suffix.count))
            guard !language.isEmpty else { return nil }

            return (language, part)
        }
        return nil
    }
}
