//  Expression.swift
//  The tiny pure expression tree templates build problems and answers out of.
//
//  This is deliberately NOT a computer algebra system. Templates know their own derivative
//  in closed form and assemble it structurally; the only work done here is the mechanical
//  tidying a person does on paper — flattening, folding constants, and collecting like
//  terms. The offline SymPy gate (Tools/verify_templates) is what proves the results right.

/// The named functions v1 needs. Derivatives only, so this stays small on purpose.
public enum MathFunction: String, Hashable, Sendable, CaseIterable {
    case sin
    case cos
    case tan
    case sec
    case csc
    case cot
    case ln
    case exp
    case sqrt
}

/// An exact symbolic expression.
public indirect enum Expression: Hashable, Sendable {
    case constant(Rational)
    case symbol(String)
    case sum([Expression])
    case product([Expression])
    case power(Expression, Expression)
    case function(MathFunction, Expression)
}

// MARK: - Construction helpers

public extension Expression {
    static let x = Expression.symbol("x")
    static let y = Expression.symbol("y")
    static let zero = Expression.constant(.zero)
    static let one = Expression.constant(.one)

    static func integer(_ value: Int) -> Expression { .constant(Rational(value)) }

    static func fraction(_ numerator: Int, _ denominator: Int) -> Expression {
        .constant(Rational(numerator, denominator))
    }

    static func + (lhs: Expression, rhs: Expression) -> Expression {
        Expression.sum([lhs, rhs]).simplified()
    }

    static func - (lhs: Expression, rhs: Expression) -> Expression {
        Expression.sum([lhs, rhs.negated]).simplified()
    }

    static func * (lhs: Expression, rhs: Expression) -> Expression {
        Expression.product([lhs, rhs]).simplified()
    }

    static func / (lhs: Expression, rhs: Expression) -> Expression {
        Expression.product([lhs, .power(rhs, .integer(-1))]).simplified()
    }

    var negated: Expression {
        Expression.product([.integer(-1), self]).simplified()
    }

    func raised(to exponent: Expression) -> Expression {
        Expression.power(self, exponent).simplified()
    }

    func raised(to exponent: Int) -> Expression {
        Expression.power(self, .integer(exponent)).simplified()
    }

    /// A ratio kept as an explicit numerator over denominator — the shape the quotient rule
    /// produces and the shape LaTeX should render as `\frac{...}{...}`.
    static func ratio(_ numerator: Expression, over denominator: Expression) -> Expression {
        Expression.product([numerator, .power(denominator, .integer(-1))]).simplified()
    }

    var isZero: Bool {
        if case let .constant(value) = self { return value.isZero }
        return false
    }

    var isOne: Bool {
        if case let .constant(value) = self { return value.isOne }
        return false
    }

    /// The rational constant this expression is, if it is one.
    var constantValue: Rational? {
        if case let .constant(value) = self { return value }
        return nil
    }
}
