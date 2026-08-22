//  TopicModule.swift
//  How a topic plugs into the app.
//
//  Registration is static — one protocol conformance in the topic's own directory, plus
//  one line in `TopicRegistry.standard`. No reflection, no Objective-C runtime discovery,
//  no dynamic loading: the set of topics is knowable by reading two files.

/// A topic: a family of problems sharing an instruction and a set of sub-types.
public protocol TopicModule: Sendable {
    var id: TopicID { get }
    var displayName: String { get }
    /// Sub-types in presentation order. The ladder and the dashboard key on these.
    var subTypes: [SubType] { get }
    /// Every template this topic owns, in presentation order.
    var templates: [any ProblemTemplate] { get }
}

public extension TopicModule {
    /// The templates belonging to one sub-type.
    func templates(for subType: SubTypeID) -> [any ProblemTemplate] {
        templates.filter { $0.subTypeID == subType }
    }

    /// The templates usable at `difficulty`, optionally narrowed to one sub-type.
    /// A `nil` sub-type means "random mix across this topic".
    func templates(for subType: SubTypeID?, difficulty: Int) -> [any ProblemTemplate] {
        templates.filter { template in
            (subType == nil || template.subTypeID == subType)
                && template.difficultyRange.contains(difficulty)
        }
    }

    /// The `(topic, sub-type)` pairs this topic contributes to the ladder and dashboard.
    var practiceKeys: [PracticeKey] {
        subTypes.map { PracticeKey(topic: id, subType: $0.id) }
    }

    func subType(_ subTypeID: SubTypeID) -> SubType? {
        subTypes.first { $0.id == subTypeID }
    }
}
