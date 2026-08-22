//  SeededGenerator.swift
//  Deterministic randomness for the whole core.
//
//  Every template and selector takes an injected `RandomNumberGenerator`. No free call to
//  `.random(in:)`, `.randomElement()` or `.shuffled()` appears anywhere in MathPracticeCore
//  — a generated problem persists its seed and reproduces byte-for-byte from it.

/// SplitMix64 — the reference deterministic 64-bit generator.
///
/// Chosen because its state is a single `UInt64`, so a `GeneratedProblem` can persist its
/// seed and be regenerated identically on any device, on any platform, at any time.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Seeded draws used by templates and selectors.
///
/// These are deliberately *not* extensions on `RandomNumberGenerator` in general use —
/// they are the only sanctioned source of variation in core, so every draw is auditable.
public extension RandomNumberGenerator {
    /// A uniform integer in `range`. Traps only on an empty range, which is a programmer error.
    mutating func drawInt(in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound, "empty draw range")
        let span = UInt64(range.upperBound - range.lowerBound) &+ 1
        return range.lowerBound + Int(unbiased(upperBound: span))
    }

    /// A uniform integer in `range` excluding zero. Used for coefficients that must not vanish.
    mutating func drawNonZeroInt(in range: ClosedRange<Int>) -> Int {
        var value = drawInt(in: range)
        var guardCount = 0
        while value == 0 && guardCount < 64 {
            value = drawInt(in: range)
            guardCount += 1
        }
        return value == 0 ? max(1, range.upperBound) : value
    }

    /// A uniform element of `elements`. Returns `nil` only for an empty collection.
    mutating func drawElement<Element>(from elements: [Element]) -> Element? {
        guard !elements.isEmpty else { return nil }
        return elements[drawInt(in: 0...(elements.count - 1))]
    }

    /// `true` with probability `numerator / denominator`.
    mutating func drawBool(numerator: Int, denominator: Int) -> Bool {
        precondition(denominator > 0, "denominator must be positive")
        return drawInt(in: 1...denominator) <= numerator
    }

    /// A deterministic shuffle. Fisher–Yates driven by this generator, never `.shuffled()`.
    mutating func drawShuffled<Element>(_ elements: [Element]) -> [Element] {
        var result = elements
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            let swapIndex = drawInt(in: 0...index)
            result.swapAt(index, swapIndex)
        }
        return result
    }

    /// Lemire-style rejection sampling — uniform, and identical on every platform.
    private mutating func unbiased(upperBound: UInt64) -> UInt64 {
        guard upperBound > 1 else { return 0 }
        let threshold = (0 &- upperBound) % upperBound
        while true {
            let value = next()
            if value >= threshold {
                return value % upperBound
            }
        }
    }
}
