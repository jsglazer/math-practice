//  RevealMachine.swift
//  The reveal loop, as a pure state machine over (answerShown, stepsShown).
//
//  The app never accepts, stores, renders an input field for, or compares a typed answer.
//  Correctness is a self-reported enum. This type is the whole disclosure policy:
//  everything stays hidden until asked for, steps come one at a time, and asking for a
//  step after the answer is already out returns the complete derivation at once — there is
//  nothing left to protect.

/// How much of a problem has been disclosed.
public struct RevealState: Hashable, Sendable {
    public private(set) var answerShown: Bool
    public private(set) var stepsShown: Int

    public init(answerShown: Bool = false, stepsShown: Int = 0) {
        self.answerShown = answerShown
        self.stepsShown = max(0, stepsShown)
    }

    fileprivate mutating func showAnswer() { answerShown = true }
    fileprivate mutating func showSteps(upTo count: Int) { stepsShown = max(stepsShown, count) }
}

/// What the user asked for.
public enum RevealRequest: Hashable, Sendable {
    /// The `a` key in the proven interaction model.
    case answer
    /// The `s` key.
    case step
}

/// What the reveal produced.
public enum RevealOutput: Hashable, Sendable {
    /// The answer, as LaTeX.
    case answer(latex: String)
    /// Exactly one further step, with its 1-based number.
    case step(number: Int, step: SolutionStep)
    /// The complete derivation, released at once because the answer was already shown.
    case allSteps([SolutionStep])
    /// Every step has already been shown and the answer has not been asked for.
    case noFurtherSteps
}

/// Drives one problem's disclosure. A value type: hand it a state, get a new state back.
public struct RevealMachine: Sendable {
    public let answerLatex: String
    public let steps: [SolutionStep]

    public init(answerLatex: String, steps: [SolutionStep]) {
        self.answerLatex = answerLatex
        self.steps = steps
    }

    public init(problem: GeneratedProblem) {
        self.init(answerLatex: problem.answerLatex, steps: problem.steps)
    }

    /// Applies one request. Pure: same state and request always give the same result.
    public func apply(_ request: RevealRequest, to state: RevealState) -> (state: RevealState, output: RevealOutput) {
        var next = state
        switch request {
        case .answer:
            next.showAnswer()
            return (next, .answer(latex: answerLatex))

        case .step where state.answerShown:
            // Nothing left to gate — release the whole derivation.
            next.showSteps(upTo: steps.count)
            return (next, .allSteps(steps))

        case .step:
            guard state.stepsShown < steps.count else {
                return (next, .noFurtherSteps)
            }
            let index = state.stepsShown
            next.showSteps(upTo: index + 1)
            return (next, .step(number: index + 1, step: steps[index]))
        }
    }

    /// The steps currently visible for `state`, for a view rebuilding itself from scratch.
    public func visibleSteps(for state: RevealState) -> [SolutionStep] {
        Array(steps.prefix(state.stepsShown))
    }
}
