//  Rational.swift
//  Exact rational arithmetic. Templates never touch floating point, so a generated answer
//  is bit-identical on every device and directly comparable to the SymPy golden fixture.

/// An exact rational number, always stored reduced with a positive denominator.
public struct Rational: Hashable, Sendable, Comparable {
    public let numerator: Int
    public let denominator: Int

    public static let zero = Rational(0)
    public static let one = Rational(1)

    public init(_ numerator: Int, _ denominator: Int = 1) {
        precondition(denominator != 0, "rational with zero denominator")
        let sign = denominator < 0 ? -1 : 1
        let divisor = Rational.greatestCommonDivisor(abs(numerator), abs(denominator))
        // A zero numerator reduces to 0/1 rather than 0/n, so equality stays structural.
        if numerator == 0 {
            self.numerator = 0
            self.denominator = 1
        } else {
            self.numerator = sign * numerator / divisor
            self.denominator = abs(denominator) / divisor
        }
    }

    public var isZero: Bool { numerator == 0 }
    public var isOne: Bool { numerator == 1 && denominator == 1 }
    public var isNegative: Bool { numerator < 0 }
    public var isInteger: Bool { denominator == 1 }
    public var magnitude: Rational { Rational(abs(numerator), denominator) }
    public var negated: Rational { Rational(-numerator, denominator) }

    public var reciprocal: Rational {
        precondition(!isZero, "reciprocal of zero")
        return Rational(denominator, numerator)
    }

    public static func + (lhs: Rational, rhs: Rational) -> Rational {
        Rational(
            lhs.numerator * rhs.denominator + rhs.numerator * lhs.denominator,
            lhs.denominator * rhs.denominator
        )
    }

    public static func - (lhs: Rational, rhs: Rational) -> Rational {
        lhs + rhs.negated
    }

    public static func * (lhs: Rational, rhs: Rational) -> Rational {
        Rational(lhs.numerator * rhs.numerator, lhs.denominator * rhs.denominator)
    }

    public static func / (lhs: Rational, rhs: Rational) -> Rational {
        lhs * rhs.reciprocal
    }

    public static func += (lhs: inout Rational, rhs: Rational) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout Rational, rhs: Rational) {
        lhs = lhs - rhs
    }

    public static func *= (lhs: inout Rational, rhs: Rational) {
        lhs = lhs * rhs
    }

    public static func /= (lhs: inout Rational, rhs: Rational) {
        lhs = lhs / rhs
    }

    public static func < (lhs: Rational, rhs: Rational) -> Bool {
        lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
    }

    private static func greatestCommonDivisor(_ lhs: Int, _ rhs: Int) -> Int {
        var a = lhs
        var b = rhs
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a == 0 ? 1 : a
    }
}

public extension Rational {
    /// `self` raised to an integer power. Templates only ever need integer exponents here.
    func raised(to exponent: Int) -> Rational {
        guard exponent != 0 else { return .one }
        let base = exponent < 0 ? reciprocal : self
        var result = Rational.one
        for _ in 0..<abs(exponent) {
            result *= base
        }
        return result
    }
}
