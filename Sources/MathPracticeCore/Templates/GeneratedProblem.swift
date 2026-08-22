//  GeneratedProblem.swift
//  A problem instance, frozen with everything needed to reproduce it exactly.

/// One generated problem. Persisting `templateID`, `difficulty` and `seed` is enough to
/// regenerate every other field byte-for-byte, but all of it is stored anyway so a frozen
/// worksheet stays readable even if a template is later revised.
public struct GeneratedProblem: Hashable, Sendable, Codable {
    public let templateID: TemplateID
    public let topicID: TopicID
    public let subTypeID: SubTypeID
    public let difficulty: Int
    public let seed: UInt64
    public let parameters: [ProblemParameter]
    public let instruction: String
    public let promptLatex: String
    public let answerLatex: String
    public let steps: [SolutionStep]
    public let canonicalPrompt: String
    public let canonicalAnswer: String
    public let verificationRule: VerificationRule

    public init(
        templateID: TemplateID,
        topicID: TopicID,
        subTypeID: SubTypeID,
        difficulty: Int,
        seed: UInt64,
        parameters: [ProblemParameter],
        instruction: String,
        promptLatex: String,
        answerLatex: String,
        steps: [SolutionStep],
        canonicalPrompt: String,
        canonicalAnswer: String,
        verificationRule: VerificationRule
    ) {
        self.templateID = templateID
        self.topicID = topicID
        self.subTypeID = subTypeID
        self.difficulty = difficulty
        self.seed = seed
        self.parameters = parameters
        self.instruction = instruction
        self.promptLatex = promptLatex
        self.answerLatex = answerLatex
        self.steps = steps
        self.canonicalPrompt = canonicalPrompt
        self.canonicalAnswer = canonicalAnswer
        self.verificationRule = verificationRule
    }

    public var practiceKey: PracticeKey {
        PracticeKey(topic: topicID, subType: subTypeID)
    }
}

public extension ProblemTemplate {
    /// Generates a reproducible problem instance for `seed`.
    func generate(topicID: TopicID, difficulty: Int, seed: UInt64) -> GeneratedProblem {
        var generator = RandomSource(seed: seed)
        let clamped = min(max(difficulty, difficultyRange.lowerBound), difficultyRange.upperBound)
        let draw = draw(difficulty: clamped, using: &generator)
        return GeneratedProblem(
            templateID: id,
            topicID: topicID,
            subTypeID: subTypeID,
            difficulty: difficulty,
            seed: seed,
            parameters: draw.parameters,
            instruction: instruction,
            promptLatex: draw.problem.latex,
            answerLatex: draw.answer.latex,
            steps: draw.steps,
            canonicalPrompt: draw.problem.canonical,
            canonicalAnswer: draw.answer.canonical,
            verificationRule: verificationRule
        )
    }
}
