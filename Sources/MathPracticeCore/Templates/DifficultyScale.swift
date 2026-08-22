//  DifficultyScale.swift
//  Turns a 1-10 difficulty into the parameter ranges templates draw from.
//
//  Every template scales through this one type, so "difficulty 7" means the same thing
//  across the whole app and a new topic inherits the calibration for free.

/// The parameter envelope for a given difficulty.
public struct DifficultyScale: Hashable, Sendable {
    public static let bounds = 1...10

    public let difficulty: Int

    public init(difficulty: Int) {
        self.difficulty = min(max(difficulty, DifficultyScale.bounds.lowerBound), DifficultyScale.bounds.upperBound)
    }

    /// Coefficients stay small and positive at the bottom of the ladder and gain sign and
    /// magnitude as it climbs.
    public var coefficientRange: ClosedRange<Int> {
        let upper = 2 + difficulty
        return allowsNegativeCoefficients ? (-upper)...upper : 1...upper
    }

    public var allowsNegativeCoefficients: Bool { difficulty >= 3 }

    /// Exponents grow slowly — a degree-7 term is hard to differentiate by hand only
    /// because of arithmetic, which is not the skill being drilled.
    public var exponentRange: ClosedRange<Int> {
        2...(2 + (difficulty + 1) / 2)
    }

    /// Inner multipliers for chain-rule arguments, kept smaller than outer coefficients.
    public var innerCoefficientRange: ClosedRange<Int> {
        let upper = 1 + (difficulty + 1) / 2
        return allowsNegativeCoefficients ? (-upper)...upper : 1...upper
    }

    /// Constant terms. Absent entirely at difficulty 1 so the first problems are one-term.
    public var constantRange: ClosedRange<Int> {
        difficulty <= 1 ? 0...0 : (-(1 + difficulty))...(1 + difficulty)
    }
}
