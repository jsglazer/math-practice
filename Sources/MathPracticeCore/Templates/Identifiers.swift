//  Identifiers.swift
//  Stable string identities for topics, sub-types and templates.
//
//  These strings are persisted in the event log and in golden fixtures, so they are part
//  of the data contract: renaming one is a migration, not a refactor.

/// Shared `Codable` behaviour for the string-backed identifier types.
///
/// Without this the compiler's memberwise synthesis would encode each identifier as
/// `{"rawValue": "..."}`, which would make the golden fixtures and exported packs
/// needlessly noisy — and those files are read by humans and by Python.
public protocol StringIdentifier: RawRepresentable, Codable, Hashable, Sendable
where RawValue == String {
    init(rawValue: String)
}

public extension StringIdentifier {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Identifies a topic — derivatives in v1, integrals and limits later.
public struct TopicID: StringIdentifier, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// Identifies a sub-type inside a topic — product rule, chain rule, and so on.
public struct SubTypeID: StringIdentifier, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// Identifies a single problem template inside a sub-type.
public struct TemplateID: StringIdentifier, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// The `(topic, sub-type)` pair the difficulty ladder and the dashboard are keyed on.
public struct PracticeKey: Hashable, Sendable, Codable, CustomStringConvertible {
    public let topic: TopicID
    public let subType: SubTypeID

    public init(topic: TopicID, subType: SubTypeID) {
        self.topic = topic
        self.subType = subType
    }

    public var description: String { "\(topic.rawValue)/\(subType.rawValue)" }
}

/// A named sub-type within a topic.
public struct SubType: Hashable, Sendable, Identifiable {
    public let id: SubTypeID
    public let displayName: String

    public init(id: SubTypeID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}
