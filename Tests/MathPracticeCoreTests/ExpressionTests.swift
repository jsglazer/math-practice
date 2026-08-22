//  ExpressionTests.swift
//  The expression tree and its two renderers. Everything a template produces flows through
//  here, so a rendering slip would corrupt every problem in the app.

import Testing
@testable import MathPracticeCore

@Suite("Expressions")
struct ExpressionTests {
    // MARK: - Rationals

    @Test("Rationals reduce on construction")
    func rationalsReduce() {
        #expect(Rational(4, 8) == Rational(1, 2))
        #expect(Rational(-6, -4) == Rational(3, 2))
        #expect(Rational(3, -6) == Rational(-1, 2))
        #expect(Rational(0, 7) == Rational.zero)
    }

    @Test("Rational arithmetic is exact")
    func rationalArithmetic() {
        #expect(Rational(1, 3) + Rational(1, 6) == Rational(1, 2))
        #expect(Rational(2, 3) * Rational(3, 4) == Rational(1, 2))
        #expect(Rational(1, 2) / Rational(1, 4) == Rational(2))
        #expect(Rational(2).raised(to: -2) == Rational(1, 4))
    }

    // MARK: - Simplification

    @Test("Sums fold constants and drop zeros")
    func sumsFold() {
        #expect(Expression.sum([.integer(2), .integer(3), .x]).simplified() == .sum([.x, .integer(5)]))
        #expect(Expression.sum([.x, .zero]).simplified() == .x)
        #expect(Expression.sum([]).simplified() == .zero)
    }

    @Test("Like terms collect, keeping first-appearance order")
    func likeTermsCollect() {
        let expression = Expression.sum([powerTerm(3, 2), powerTerm(1, 1), powerTerm(5, 2)]).simplified()
        #expect(expression == .sum([powerTerm(8, 2), .x]))
    }

    @Test("Terms that cancel disappear entirely")
    func termsCancel() {
        #expect(Expression.sum([powerTerm(3, 2), powerTerm(-3, 2)]).simplified() == .zero)
    }

    @Test("Products fold coefficients and merge equal bases")
    func productsFold() {
        #expect(Expression.product([.integer(2), .integer(3), .x]).simplified() == powerTerm(6, 1))
        #expect(Expression.product([.x, .power(.x, .integer(2))]).simplified() == .power(.x, .integer(3)))
        #expect(Expression.product([.x, .integer(0)]).simplified() == .zero)
        #expect(Expression.product([.x, .one]).simplified() == .x)
    }

    @Test("Powers collapse the way the rules say")
    func powersCollapse() {
        #expect(Expression.power(.x, .zero).simplified() == .one)
        #expect(Expression.power(.x, .one).simplified() == .x)
        #expect(Expression.power(.integer(2), .integer(3)).simplified() == .integer(8))
        #expect(Expression.power(.power(.x, .integer(2)), .integer(3)).simplified() == .power(.x, .integer(6)))
    }

    @Test("Simplification is idempotent")
    func simplificationIsIdempotent() {
        let messy = Expression.sum([
            .product([.integer(2), .x, .integer(3)]),
            .power(.power(.x, .integer(2)), .integer(1)),
            .integer(0)
        ])
        let once = messy.simplified()
        #expect(once.simplified() == once)
    }

    @Test("Division becomes a negative power")
    func divisionIsANegativePower() {
        let ratio = Expression.ratio(.integer(1), over: .x)
        #expect(ratio == .power(.x, .integer(-1)))
    }

    // MARK: - LaTeX

    @Test("Polynomials render with a minus join, never a plus-minus")
    func polynomialLatex() {
        let expression = Expression.sum([powerTerm(3, 2), powerTerm(-4, 1), .integer(-5)]).simplified()
        #expect(expression.latex == "3 x^{2} - 4 x - 5")
    }

    @Test("Sums used as factors are bracketed")
    func factorsAreBracketed() {
        let u = Expression.sum([.x, .integer(1)]).simplified()
        let v = Expression.sum([.x, .integer(-2)]).simplified()
        #expect(Expression.product([u, v]).simplified().latex == "\\left(x + 1\\right) \\left(x - 2\\right)")
    }

    @Test("A coefficient in front of a sum brackets it")
    func coefficientBracketsSum() {
        let sum = Expression.sum([.x, .integer(1)]).simplified()
        #expect(Expression.product([.integer(3), sum]).simplified().latex == "3 \\left(x + 1\\right)")
    }

    @Test("Negative exponents render as a fraction")
    func negativeExponentsRenderAsFractions() {
        #expect(powerTerm(4, -2).latex == "\\frac{4}{x^{2}}")
    }

    @Test("A lone sum in a denominator is not double-bracketed")
    func denominatorNeedsNoBrackets() {
        let denominator = Expression.sum([.x, .integer(4)]).simplified()
        #expect(Expression.ratio(.integer(2), over: denominator).latex == "\\frac{2}{x + 4}")
    }

    @Test("Half powers render as radicals")
    func halfPowersRenderAsRadicals() {
        #expect(Expression.power(.x, .fraction(1, 2)).latex == "\\sqrt{x}")
        let halfOverRoot = Expression.product([.fraction(1, 2), .power(.x, .fraction(-1, 2))]).simplified()
        #expect(halfOverRoot.latex == "\\frac{1}{2 \\sqrt{x}}")
    }

    @Test("Trig powers use the shorthand form")
    func trigPowerShorthand() {
        let expression = Expression.power(.function(.sec, .x), .integer(2)).simplified()
        #expect(expression.latex == "\\sec^{2}\\left(x\\right)")
    }

    @Test("Exponentials render as e to a power")
    func exponentialLatex() {
        #expect(Expression.function(.exp, powerTerm(2, 1)).latex == "e^{2 x}")
    }

    // MARK: - Canonical form

    @Test("Canonical form is fully parenthesised")
    func canonicalIsParenthesised() {
        let expression = Expression.sum([powerTerm(3, 2), .integer(1)]).simplified()
        #expect(expression.canonical == "((3*(x)**(2)) + 1)")
    }

    @Test("ln maps to SymPy's log")
    func lnMapsToLog() {
        #expect(Expression.function(.ln, .x).canonical == "log(x)")
        #expect(Expression.function(.exp, .x).canonical == "exp(x)")
    }

    @Test("Fractions survive the crossing into SymPy")
    func fractionsAreExplicit() {
        #expect(Expression.fraction(-5, 2).canonical == "Rational(-5, 2)")
        #expect(Expression.integer(-5).canonical == "-5")
    }
}
