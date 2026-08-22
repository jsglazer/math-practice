//  TopicRegistry.swift
//  The one place the app learns which topics exist.
//
//  Adding topic 2 (integrals) means: create `Topics/Integrals/`, conform `TopicModule`,
//  and add one element to the array literal in `standard`. Nothing else in the app —
//  selector, router, ladder, dashboard, schema — needs to change, and the test suite
//  proves it by driving all four through a topic the app has never heard of.

/// A resolved set of topics. Injected, never a global, so tests substitute their own.
public struct TopicRegistry: Sendable {
    public let topics: [any TopicModule]

    public init(topics: [any TopicModule]) {
        self.topics = topics
    }

    /// The shipping topic set. THIS ARRAY LITERAL is the single line a new topic touches.
    public static let standard = TopicRegistry(topics: [
        DerivativesTopic()
    ])

    public func topic(_ id: TopicID) -> (any TopicModule)? {
        topics.first { $0.id == id }
    }

    /// Resolves a template by identifier, along with the topic that owns it.
    public func resolve(_ templateID: TemplateID) -> (topic: any TopicModule, template: any ProblemTemplate)? {
        for topic in topics {
            if let template = topic.templates.first(where: { $0.id == templateID }) {
                return (topic, template)
            }
        }
        return nil
    }

    /// Every `(topic, sub-type)` pair across every registered topic, in registration order.
    public var practiceKeys: [PracticeKey] {
        topics.flatMap(\.practiceKeys)
    }

    public func displayName(for key: PracticeKey) -> String {
        guard let topic = topic(key.topic) else { return key.description }
        guard let subType = topic.subType(key.subType) else { return topic.displayName }
        return "\(topic.displayName) · \(subType.displayName)"
    }
}
