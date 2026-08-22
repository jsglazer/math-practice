//  DerivativeBuilders.swift
//  Shared construction helpers for the derivative templates.
//
//  Every template assembles its answer from these, so the power rule is written once and
//  the SymPy gate is checking one implementation rather than sixteen transcriptions.

/// `coefficient * x^exponent`.
func powerTerm(_ coefficient: Int, _ exponent: Int) -> Expression {
    Expression.product([.integer(coefficient), .power(.x, .integer(exponent))]).simplified()
}

/// `d/dx [coefficient * x^exponent]` = `coefficient*exponent * x^(exponent-1)`.
func powerRuleDerivative(_ coefficient: Int, _ exponent: Int) -> Expression {
    Expression.product([
        .integer(coefficient * exponent),
        .power(.x, .integer(exponent - 1))
    ]).simplified()
}

/// `coefficient * f(inner)`.
func scaled(_ coefficient: Int, _ expression: Expression) -> Expression {
    Expression.product([.integer(coefficient), expression]).simplified()
}

/// The trig functions a v1 problem may be built from, with their derivatives.
enum TrigChoice: String, CaseIterable, Sendable {
    case sine
    case cosine

    var function: MathFunction {
        switch self {
        case .sine: return .sin
        case .cosine: return .cos
        }
    }

    /// `d/du f(u)`, as an expression in `argument`. The chain factor is applied by the caller.
    func derivative(of argument: Expression) -> Expression {
        switch self {
        case .sine: return .function(.cos, argument)
        case .cosine: return Expression.function(.sin, argument).negated
        }
    }

    var displayName: String {
        switch self {
        case .sine: return "sine"
        case .cosine: return "cosine"
        }
    }
}

/// A `u = ..., v = ...` narrative line, used by the product and quotient templates.
func namedPartsStep(
    title: String,
    first: (name: String, expression: Expression),
    second: (name: String, expression: Expression)
) -> SolutionStep {
    SolutionStep.narrative(
        title,
        latex: "\(first.name) = \(first.expression.latex),\\quad \(second.name) = \(second.expression.latex)"
    )
}
