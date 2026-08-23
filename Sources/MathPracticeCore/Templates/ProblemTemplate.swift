//  ProblemTemplate.swift
//  Problem templates are pure value types: one parameter draw in, a problem, an answer and
//  an ordered step list out.
//
//  There is no runtime CAS, no pre-generated problem warehouse, and no depletion or
//  regeneration logic anywhere in the app. A template knows its own derivative in closed
//  form; the offline SymPy gate is what proves that closed form correct.

/// One drawn parameter, recorded so a problem instance reproduces byte-for-byte.
public struct ProblemParameter: Hashable, Sendable, Codable {
    public let name: String
    public let value: Int

    public init(name: String, value: Int) {
        self.name = name
        self.value = value
    }
}

/// One line of a worked solution.
///
/// `canonical` is present only for steps that state an expression; narrative steps such as
/// "Apply the product rule" carry `nil`, and the SymPy gate skips them.
public struct SolutionStep: Hashable, Sendable, Codable {
    public let title: String
    public let latex: String
    public let canonical: String?

    public init(title: String, latex: String, canonical: String? = nil) {
        self.title = title
        self.latex = latex
        self.canonical = canonical
    }

    /// A step that states an expression, carrying both renderings.
    public init(title: String, expression: Expression) {
        self.title = title
        self.latex = expression.latex
        self.canonical = expression.canonical
    }

    /// A step that only says what to do next.
    public static func narrative(_ title: String, latex: String) -> SolutionStep {
        SolutionStep(title: title, latex: latex, canonical: nil)
    }
}

/// What the offline verifier must do to check a template's answer.
public enum VerificationRule: String, Hashable, Sendable, Codable {
    /// `answer` must equal `d/dx problem`.
    case derivative
    /// `answer` must equal `∂/∂x problem`, holding y constant.
    case partialDerivativeX = "partial-x"
    /// `answer` must equal `∂/∂y problem`, holding x constant.
    case partialDerivativeY = "partial-y"
}

/// What a template produces from one parameter draw, before it is stamped with its seed.
public struct ProblemDraw: Hashable, Sendable {
    public let parameters: [ProblemParameter]
    public let problem: Expression
    public let answer: Expression
    public let steps: [SolutionStep]

    public init(
        parameters: [ProblemParameter],
        problem: Expression,
        answer: Expression,
        steps: [SolutionStep]
    ) {
        self.parameters = parameters
        self.problem = problem
        self.answer = answer
        self.steps = steps
    }
}

/// A pure problem generator. Conformances are value types in `Topics/`.
public protocol ProblemTemplate: Sendable {
    var id: TemplateID { get }
    var subTypeID: SubTypeID { get }
    var displayName: String { get }
    /// The difficulty band this template is appropriate for. The selector never offers a
    /// template outside its band, which is how difficulty 1 stays genuinely easy.
    var difficultyRange: ClosedRange<Int> { get }
    var verificationRule: VerificationRule { get }
    /// The instruction shown above the problem, e.g. "Differentiate with respect to x".
    var instruction: String { get }

    /// Draws one problem. Must be a pure function of `(difficulty, generator state)`.
    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw
}

public extension ProblemTemplate {
    var instruction: String { "Differentiate with respect to x" }
    var verificationRule: VerificationRule { .derivative }
}
