//  Simplification.swift
//  Structural tidying only — flatten, fold exact constants, merge equal powers, collect
//  like terms. Term order is preserved throughout so a template controls how its problem
//  reads on the page, and so two runs of the same seed produce byte-identical output.

public extension Expression {
    /// The canonical form of this expression. Idempotent: `e.simplified() == e.simplified().simplified()`.
    func simplified() -> Expression {
        switch self {
        case .constant, .symbol:
            return self
        case let .sum(terms):
            return Expression.simplifySum(terms.map { $0.simplified() })
        case let .product(factors):
            return Expression.simplifyProduct(factors.map { $0.simplified() })
        case let .power(base, exponent):
            return Expression.simplifyPower(base.simplified(), exponent.simplified())
        case let .function(name, argument):
            return .function(name, argument.simplified())
        }
    }

    /// Splits a term into its rational coefficient and the rest, e.g. `-3x^2 -> (-3, x^2)`.
    /// Used both by like-term collection and by the LaTeX renderer's sign handling.
    func splitCoefficient() -> (coefficient: Rational, rest: Expression) {
        switch self {
        case let .constant(value):
            return (value, .one)
        case let .product(factors):
            guard let first = factors.first, case let .constant(value) = first else {
                return (.one, self)
            }
            let remainder = Array(factors.dropFirst())
            if remainder.isEmpty { return (value, .one) }
            if remainder.count == 1 { return (value, remainder[0]) }
            return (value, .product(remainder))
        default:
            return (.one, self)
        }
    }

    // MARK: - Sum

    private static func simplifySum(_ terms: [Expression]) -> Expression {
        var flattened: [Expression] = []
        var constantTotal = Rational.zero
        for term in terms {
            switch term {
            case let .sum(inner):
                for nested in inner {
                    if case let .constant(value) = nested {
                        constantTotal += value
                    } else {
                        flattened.append(nested)
                    }
                }
            case let .constant(value):
                constantTotal += value
            default:
                flattened.append(term)
            }
        }

        var collected = collectLikeTerms(flattened)
        // The constant term reads last, the way it is written on paper.
        if !constantTotal.isZero {
            collected.append(.constant(constantTotal))
        }
        if collected.isEmpty { return .zero }
        if collected.count == 1 { return collected[0] }
        return .sum(collected)
    }

    /// Merges terms sharing the same non-constant part, keeping first-appearance order.
    private static func collectLikeTerms(_ terms: [Expression]) -> [Expression] {
        var order: [Expression] = []
        var coefficients: [Expression: Rational] = [:]
        for term in terms {
            let (coefficient, rest) = term.splitCoefficient()
            if let existing = coefficients[rest] {
                coefficients[rest] = existing + coefficient
            } else {
                coefficients[rest] = coefficient
                order.append(rest)
            }
        }
        return order.compactMap { rest in
            guard let coefficient = coefficients[rest], !coefficient.isZero else { return nil }
            return simplifyProduct([.constant(coefficient), rest])
        }
    }

    // MARK: - Product

    private static func simplifyProduct(_ factors: [Expression]) -> Expression {
        var coefficient = Rational.one
        // (base, exponent) pairs in first-appearance order, so `x * x^2` becomes `x^3`.
        var bases: [Expression] = []
        var exponents: [Expression: Rational] = [:]

        func absorb(_ factor: Expression) {
            switch factor {
            case let .constant(value):
                coefficient *= value
            case let .product(inner):
                for nested in inner { absorb(nested) }
            case let .power(base, exponent):
                if case let .constant(power) = exponent {
                    accumulate(base: base, exponent: power)
                } else {
                    accumulate(base: factor, exponent: .one)
                }
            default:
                accumulate(base: factor, exponent: .one)
            }
        }

        func accumulate(base: Expression, exponent: Rational) {
            if let existing = exponents[base] {
                exponents[base] = existing + exponent
            } else {
                exponents[base] = exponent
                bases.append(base)
            }
        }

        for factor in factors { absorb(factor) }

        if coefficient.isZero { return .zero }

        var rebuilt: [Expression] = []
        for base in bases {
            guard let exponent = exponents[base], !exponent.isZero else { continue }
            if exponent.isOne {
                rebuilt.append(base)
            } else if case let .constant(value) = base, exponent.isInteger {
                // A folded numeric power such as `2^3` belongs in the coefficient.
                coefficient *= value.raised(to: exponent.numerator)
            } else {
                rebuilt.append(.power(base, .constant(exponent)))
            }
        }

        if coefficient.isZero { return .zero }
        if rebuilt.isEmpty { return .constant(coefficient) }
        if coefficient.isOne {
            return rebuilt.count == 1 ? rebuilt[0] : .product(rebuilt)
        }
        return .product([.constant(coefficient)] + rebuilt)
    }

    // MARK: - Expansion

    /// Distributes products over sums (and non-negative-integer powers of sums), then
    /// folds and collects the result. `simplified()` alone leaves a factored product like
    /// `-40x^4(x^2+6)` untouched — this is for the templates that instead want the answer
    /// stated as one collected polynomial, the way it is written after "expand and collect".
    func expanded() -> Expression {
        switch self {
        case .constant, .symbol:
            return self
        case let .sum(terms):
            return Expression.sum(terms.map { $0.expanded() }).simplified()
        case let .product(factors):
            return Expression.distribute(factors.map { $0.expanded() }).simplified()
        case let .power(base, exponent):
            let expandedBase = base.expanded()
            if case let .constant(power) = exponent, power.isInteger, power.numerator >= 0,
               case .sum = expandedBase {
                let count = power.numerator
                guard count > 0 else { return .one }
                var result = expandedBase
                for _ in 1..<count {
                    result = Expression.distribute([result, expandedBase]).simplified()
                }
                return result
            }
            return Expression.power(expandedBase, exponent).simplified()
        case let .function(name, argument):
            return .function(name, argument.expanded())
        }
    }

    /// Multiplies out every sum factor against every other factor:
    /// `a * (b + c) * (d + e)` -> `abd + abe + acd + ace`.
    private static func distribute(_ factors: [Expression]) -> Expression {
        var terms: [[Expression]] = [[]]
        for factor in factors {
            let factorTerms: [Expression]
            if case let .sum(inner) = factor {
                factorTerms = inner
            } else {
                factorTerms = [factor]
            }
            var next: [[Expression]] = []
            next.reserveCapacity(terms.count * factorTerms.count)
            for partial in terms {
                for term in factorTerms {
                    next.append(partial + [term])
                }
            }
            terms = next
        }
        let products = terms.map { Expression.product($0) }
        return products.count == 1 ? products[0] : .sum(products)
    }

    // MARK: - Power

    private static func simplifyPower(_ base: Expression, _ exponent: Expression) -> Expression {
        if case let .constant(power) = exponent {
            if power.isZero { return .one }
            if power.isOne { return base }
            if case let .constant(value) = base, power.isInteger, !value.isZero {
                return .constant(value.raised(to: power.numerator))
            }
            // (b^m)^n collapses to b^(m*n) only when both exponents are exact constants.
            if case let .power(innerBase, innerExponent) = base,
               case let .constant(innerPower) = innerExponent {
                return simplifyPower(innerBase, .constant(innerPower * power))
            }
        }
        if base.isOne { return .one }
        return .power(base, exponent)
    }
}
