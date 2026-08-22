//  ProblemSelector.swift
//  Chooses what to ask next. Multi-topic from the start, even though v1 ships one topic.
//
//  Every choice runs through the injected `RandomSource`, so a session replays exactly
//  from its seed and the tests never flake.

/// Which difficulty a request wants.
public enum DifficultySelection: Hashable, Sendable {
    /// Follow the ladder for the chosen key.
    case adaptive
    /// A level the user picked explicitly for this session.
    case fixed(Int)
}

/// What the user asked to practise. `nil` means "random mix".
public struct PracticeRequest: Hashable, Sendable {
    public let topic: TopicID?
    public let subType: SubTypeID?
    public let difficulty: DifficultySelection

    public init(topic: TopicID?, subType: SubTypeID?, difficulty: DifficultySelection) {
        self.topic = topic
        self.subType = subType
        self.difficulty = difficulty
    }
}

/// Why a request could not be served.
public enum SelectionFailure: Error, Hashable, Sendable {
    case noTopicsRegistered
    case unknownTopic(TopicID)
    /// No template covers this `(sub-type, difficulty)` combination.
    case noTemplateAvailable(PracticeKey, difficulty: Int)
}

/// Picks a topic, a sub-type, a difficulty and a template, then generates the problem.
public struct ProblemSelector: Sendable {
    public let registry: TopicRegistry

    public init(registry: TopicRegistry) {
        self.registry = registry
    }

    /// Resolves a request into a concrete problem.
    ///
    /// The `seed` for the problem is drawn from the same generator, so one session seed
    /// reproduces the whole sequence of problems.
    public func next(
        _ request: PracticeRequest,
        ladder: LadderSnapshot,
        using generator: inout RandomSource
    ) throws -> GeneratedProblem {
        guard !registry.topics.isEmpty else { throw SelectionFailure.noTopicsRegistered }

        let topic: any TopicModule
        if let requested = request.topic {
            guard let resolved = registry.topic(requested) else {
                throw SelectionFailure.unknownTopic(requested)
            }
            topic = resolved
        } else {
            guard let picked = generator.drawElement(from: registry.topics) else {
                throw SelectionFailure.noTopicsRegistered
            }
            topic = picked
        }

        let subTypeID: SubTypeID
        if let requested = request.subType {
            subTypeID = requested
        } else {
            guard let picked = generator.drawElement(from: topic.subTypes) else {
                throw SelectionFailure.noTemplateAvailable(
                    PracticeKey(topic: topic.id, subType: SubTypeID("")),
                    difficulty: 0
                )
            }
            subTypeID = picked.id
        }

        let key = PracticeKey(topic: topic.id, subType: subTypeID)
        let difficulty: Int
        switch request.difficulty {
        case .adaptive:
            difficulty = ladder.level(for: key)
        case let .fixed(level):
            difficulty = DifficultyLadder.clamp(level)
        }

        let candidates = topic.templates(for: subTypeID, difficulty: difficulty)
        // Falling back to the nearest band is better than refusing to pose a problem: a
        // sub-type whose easiest template starts at 5 should still be practisable at 3.
        let usable = candidates.isEmpty
            ? nearestBand(in: topic, subType: subTypeID, difficulty: difficulty)
            : candidates
        guard let template = generator.drawElement(from: usable) else {
            throw SelectionFailure.noTemplateAvailable(key, difficulty: difficulty)
        }

        let seed = generator.next()
        return template.generate(topicID: topic.id, difficulty: difficulty, seed: seed)
    }

    /// The templates for `subType` whose band starts closest to `difficulty`.
    private func nearestBand(
        in topic: any TopicModule,
        subType: SubTypeID,
        difficulty: Int
    ) -> [any ProblemTemplate] {
        let all = topic.templates(for: subType)
        guard !all.isEmpty else { return [] }
        let distances = all.map { template -> Int in
            if template.difficultyRange.contains(difficulty) { return 0 }
            return difficulty < template.difficultyRange.lowerBound
                ? template.difficultyRange.lowerBound - difficulty
                : difficulty - template.difficultyRange.upperBound
        }
        guard let best = distances.min() else { return [] }
        return zip(all, distances).filter { $0.1 == best }.map(\.0)
    }
}
