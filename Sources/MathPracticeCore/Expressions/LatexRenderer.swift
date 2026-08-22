//  LatexRenderer.swift
//  Expression -> LaTeX, for KaTeX to typeset in the WKWebView shell.
//
//  Pure string building: no WebKit, no SwiftUI, no I/O. The shell hands the result to
//  KaTeX; core never knows a renderer exists.

public extension Expression {
    /// A KaTeX-compatible LaTeX rendering of this expression.
    var latex: String {
        LatexRenderer.render(self)
    }
}

enum LatexRenderer {
    static func render(_ expression: Expression) -> String {
        switch expression {
        case let .constant(value):
            return renderConstant(value)
        case let .symbol(name):
            return name
        case let .sum(terms):
            return renderSum(terms)
        case let .product(factors):
            return renderProduct(factors)
        case let .power(base, exponent):
            return renderPower(base: base, exponent: exponent)
        case let .function(name, argument):
            return renderFunction(name, argument)
        }
    }

    // MARK: - Leaves

    private static func renderConstant(_ value: Rational) -> String {
        if value.isInteger { return "\(value.numerator)" }
        let sign = value.isNegative ? "-" : ""
        return "\(sign)\\frac{\(abs(value.numerator))}{\(value.denominator)}"
    }

    // MARK: - Sum

    /// Terms with a negative coefficient are folded into a `-` join rather than printed
    /// as `+ -3x`, which is what makes the output read like handwriting.
    private static func renderSum(_ terms: [Expression]) -> String {
        guard let first = terms.first else { return "0" }
        var output = render(first)
        for term in terms.dropFirst() {
            let (coefficient, rest) = term.splitCoefficient()
            if coefficient.isNegative {
                let positive = Expression.product([.constant(coefficient.magnitude), rest]).simplified()
                output += " - " + render(positive)
            } else {
                output += " + " + render(term)
            }
        }
        return output
    }

    // MARK: - Product

    /// Factors carrying a negative constant exponent, and a fractional coefficient, are
    /// pulled into a single `\frac{...}{...}` — the shape a quotient-rule answer wants.
    private static func renderProduct(_ factors: [Expression]) -> String {
        var coefficient = Rational.one
        var numerator: [Expression] = []
        // Held as expressions with their exponent already made positive, so the
        // single-factor case can print `\\frac{a}{x + 1}` without stray brackets.
        var denominator: [Expression] = []

        for factor in factors {
            switch factor {
            case let .constant(value):
                coefficient *= value
            case let .power(base, exponent):
                if case let .constant(power) = exponent, power.isNegative {
                    let flipped = power.negated
                    denominator.append(flipped.isOne ? base : .power(base, .constant(flipped)))
                } else {
                    numerator.append(factor)
                }
            default:
                numerator.append(factor)
            }
        }

        if coefficient.denominator != 1 {
            denominator.insert(.constant(Rational(coefficient.denominator)), at: 0)
        }

        let sign = coefficient.isNegative ? "-" : ""
        let magnitude = abs(coefficient.numerator)
        let showsMagnitude = magnitude != 1 || numerator.isEmpty
        // A lone sum only stays bare when nothing can run into it: no sibling factor, no
        // printed coefficient, and either a leading `-` absent or a `\\frac{}` around it.
        let numeratorCrowded = numerator.count > 1
            || showsMagnitude
            || (denominator.isEmpty && coefficient.isNegative)
        var numeratorParts = numerator.map { bracket($0, amongSiblings: numeratorCrowded) }
        if showsMagnitude {
            numeratorParts.insert("\(magnitude)", at: 0)
        }

        let numeratorText = join(numeratorParts)
        guard !denominator.isEmpty else { return sign + numeratorText }
        let denominatorParts = denominator.map { bracket($0, amongSiblings: denominator.count > 1) }
        return sign + "\\frac{\(numeratorText)}{\(join(denominatorParts))}"
    }

    /// A sum used as a factor must be bracketed, or `(x + 1)(x - 2)` reads as `x + 1x - 2`.
    /// A lone factor inside `\\frac{}{}` is already delimited, so it is left bare.
    private static func bracket(_ factor: Expression, amongSiblings: Bool) -> String {
        if case .sum = factor, amongSiblings {
            return "\\left(\(render(factor))\\right)"
        }
        return render(factor)
    }

    /// Juxtaposes factors, inserting `\cdot` only where two numerals would otherwise collide.
    private static func join(_ parts: [String]) -> String {
        guard var output = parts.first else { return "1" }
        for part in parts.dropFirst() {
            let needsDot = output.last.map { $0.isNumber } ?? false
                && part.first.map { $0.isNumber } ?? false
            output += (needsDot ? " \\cdot " : " ") + part
        }
        return output
    }

    // MARK: - Power

    private static func renderPower(base: Expression, exponent: Expression) -> String {
        // A one-half power is a radical on paper, so render it as one.
        if case let .constant(power) = exponent, power == Rational(1, 2) {
            return "\\sqrt{\(render(base))}"
        }
        // Trig and log powers are conventionally written sin^{2}(x), not (sin(x))^{2}.
        if case let .function(name, argument) = base, name.usesShorthandPower {
            return "\\\(name.latexCommand)^{\(render(exponent))}\\left(\(render(argument))\\right)"
        }
        return "\(parenthesizedBase(base))^{\(render(exponent))}"
    }

    private static func parenthesizedBase(_ base: Expression) -> String {
        switch base {
        case .symbol:
            return render(base)
        case let .constant(value) where value.isInteger && !value.isNegative:
            return render(base)
        case let .function(name, _) where name == .sqrt || name == .exp:
            return "\\left(\(render(base))\\right)"
        case .function:
            return render(base)
        default:
            return "\\left(\(render(base))\\right)"
        }
    }

    // MARK: - Functions

    private static func renderFunction(_ name: MathFunction, _ argument: Expression) -> String {
        switch name {
        case .sqrt:
            return "\\sqrt{\(render(argument))}"
        case .exp:
            return "e^{\(render(argument))}"
        default:
            return "\\\(name.latexCommand)\\left(\(render(argument))\\right)"
        }
    }
}

extension MathFunction {
    /// The KaTeX command name, without the leading backslash.
    var latexCommand: String {
        switch self {
        case .sin: return "sin"
        case .cos: return "cos"
        case .tan: return "tan"
        case .sec: return "sec"
        case .csc: return "csc"
        case .cot: return "cot"
        case .ln: return "ln"
        case .exp: return "exp"
        case .sqrt: return "sqrt"
        }
    }

    /// Whether `f^{n}(x)` is the conventional way to write a power of this function.
    var usesShorthandPower: Bool {
        switch self {
        case .sin, .cos, .tan, .sec, .csc, .cot:
            return true
        case .ln, .exp, .sqrt:
            return false
        }
    }
}
