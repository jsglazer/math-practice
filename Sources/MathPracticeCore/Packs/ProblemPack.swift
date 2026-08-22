//  ProblemPack.swift
//  LLM-authored problems, imported from a file rather than bundled.
//
//  A pack problem carries exactly the fields the golden fixture schema carries, so one
//  validator checks both: whatever the SymPy gate can verify, an import can too.

import Foundation

/// One problem inside an imported pack. Mirrors `TemplateGolden` field for field.
public struct PackProblem: Hashable, Sendable, Codable {
    /// 0-based position in the pack. Part of the problem's dedupe identity.
    public let index: Int
    public let subTypeID: SubTypeID
    public let difficulty: Int
    public let instruction: String
    public let promptLatex: String
    public let answerLatex: String
    public let steps: [SolutionStep]
    public let canonicalPrompt: String
    public let canonicalAnswer: String

    public init(
        index: Int,
        subTypeID: SubTypeID,
        difficulty: Int,
        instruction: String,
        promptLatex: String,
        answerLatex: String,
        steps: [SolutionStep],
        canonicalPrompt: String,
        canonicalAnswer: String
    ) {
        self.index = index
        self.subTypeID = subTypeID
        self.difficulty = difficulty
        self.instruction = instruction
        self.promptLatex = promptLatex
        self.answerLatex = answerLatex
        self.steps = steps
        self.canonicalPrompt = canonicalPrompt
        self.canonicalAnswer = canonicalAnswer
    }
}

/// A pack as it arrives from disk. Identified by `(identifier, version)`.
public struct ProblemPack: Hashable, Sendable, Codable {
    public let identifier: String
    public let version: Int
    public let title: String
    public let topicID: TopicID
    public let problems: [PackProblem]

    public init(
        identifier: String,
        version: Int,
        title: String,
        topicID: TopicID,
        problems: [PackProblem]
    ) {
        self.identifier = identifier
        self.version = version
        self.title = title
        self.topicID = topicID
        self.problems = problems
    }

    public var dedupeKey: String {
        DedupeKey.pack(identifier: identifier, version: version)
    }
}

/// A pack that has passed validation. Only this type can be installed.
public struct ValidatedPack: Hashable, Sendable {
    public let pack: ProblemPack

    fileprivate init(pack: ProblemPack) {
        self.pack = pack
    }

    /// The pack's problems as ordinary generated problems, so the rest of the app cannot
    /// tell an imported problem from a template-generated one.
    public func problems(instructionFallback: String = "Differentiate with respect to x") -> [GeneratedProblem] {
        pack.problems.map { problem in
            let templateID = TemplateID("pack:\(pack.identifier):\(pack.version):\(problem.index)")
            return GeneratedProblem(
                problemID: ProblemIdentifier.code(templateID: templateID, difficulty: problem.difficulty, seed: 0),
                templateID: templateID,
                topicID: pack.topicID,
                subTypeID: problem.subTypeID,
                difficulty: problem.difficulty,
                seed: 0,
                parameters: [],
                instruction: problem.instruction.isEmpty ? instructionFallback : problem.instruction,
                promptLatex: problem.promptLatex,
                answerLatex: problem.answerLatex,
                steps: problem.steps,
                canonicalPrompt: problem.canonicalPrompt,
                canonicalAnswer: problem.canonicalAnswer,
                verificationRule: .derivative
            )
        }
    }
}

/// Everything that can be wrong with a pack.
public enum PackValidationError: Hashable, Sendable, Error, CustomStringConvertible {
    case emptyIdentifier
    case nonPositiveVersion(Int)
    case emptyTitle
    case unknownTopic(TopicID)
    case noProblems
    case indexOutOfOrder(expected: Int, found: Int)
    case unknownSubType(index: Int, subType: SubTypeID)
    case difficultyOutOfRange(index: Int, difficulty: Int)
    case emptyField(index: Int, field: String)
    case noSteps(index: Int)
    case stepMissingText(index: Int, step: Int)

    public var description: String {
        switch self {
        case .emptyIdentifier: return "pack identifier is empty"
        case let .nonPositiveVersion(version): return "pack version \(version) must be 1 or greater"
        case .emptyTitle: return "pack title is empty"
        case let .unknownTopic(topic): return "unknown topic '\(topic)'"
        case .noProblems: return "pack contains no problems"
        case let .indexOutOfOrder(expected, found):
            return "problem index \(found) out of order, expected \(expected)"
        case let .unknownSubType(index, subType):
            return "problem \(index): unknown sub-type '\(subType)'"
        case let .difficultyOutOfRange(index, difficulty):
            return "problem \(index): difficulty \(difficulty) outside 1...10"
        case let .emptyField(index, field):
            return "problem \(index): '\(field)' is empty"
        case let .noSteps(index): return "problem \(index): no solution steps"
        case let .stepMissingText(index, step):
            return "problem \(index), step \(step): missing title or LaTeX"
        }
    }
}

/// Every reason a pack was rejected, gathered in one throwable value — the import reports
/// all of them at once rather than making the author fix one line per attempt.
public struct PackValidationFailure: Error, Hashable, Sendable, CustomStringConvertible {
    public let errors: [PackValidationError]

    public init(errors: [PackValidationError]) {
        self.errors = errors
    }

    public var description: String {
        errors.map(\.description).joined(separator: "; ")
    }
}

/// Validates a pack wholesale. A pack is rejected in full on any single failure — it is
/// never partially imported, so the library can never hold half a pack.
public enum PackValidator {
    public static func validate(
        _ pack: ProblemPack,
        registry: TopicRegistry
    ) -> Result<ValidatedPack, PackValidationFailure> {
        var errors: [PackValidationError] = []

        if pack.identifier.trimmed.isEmpty { errors.append(.emptyIdentifier) }
        if pack.version < 1 { errors.append(.nonPositiveVersion(pack.version)) }
        if pack.title.trimmed.isEmpty { errors.append(.emptyTitle) }
        if pack.problems.isEmpty { errors.append(.noProblems) }

        let topic = registry.topic(pack.topicID)
        if topic == nil { errors.append(.unknownTopic(pack.topicID)) }

        for (position, problem) in pack.problems.enumerated() {
            errors.append(contentsOf: validate(problem, at: position, topic: topic))
        }

        return errors.isEmpty
            ? .success(ValidatedPack(pack: pack))
            : .failure(PackValidationFailure(errors: errors))
    }
}

private extension PackValidator {
    /// Checks one problem. Split out so the wholesale pass above stays readable, and so a
    /// new required field is one edit in one place.
    static func validate(
        _ problem: PackProblem,
        at position: Int,
        topic: (any TopicModule)?
    ) -> [PackValidationError] {
        var errors: [PackValidationError] = []

        if problem.index != position {
            errors.append(.indexOutOfOrder(expected: position, found: problem.index))
        }
        if let topic, topic.subType(problem.subTypeID) == nil {
            errors.append(.unknownSubType(index: position, subType: problem.subTypeID))
        }
        if !DifficultyLadder.bounds.contains(problem.difficulty) {
            errors.append(.difficultyOutOfRange(index: position, difficulty: problem.difficulty))
        }

        let required: [(String, String)] = [
            ("promptLatex", problem.promptLatex),
            ("answerLatex", problem.answerLatex),
            ("canonicalPrompt", problem.canonicalPrompt),
            ("canonicalAnswer", problem.canonicalAnswer)
        ]
        for (field, value) in required where value.trimmed.isEmpty {
            errors.append(.emptyField(index: position, field: field))
        }

        if problem.steps.isEmpty {
            errors.append(.noSteps(index: position))
        }
        for (stepPosition, step) in problem.steps.enumerated()
        where step.title.trimmed.isEmpty || step.latex.trimmed.isEmpty {
            errors.append(.stepMissingText(index: position, step: stepPosition))
        }

        return errors
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
