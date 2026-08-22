//  RandomSource.swift
//  The one mutable randomness carrier threaded through core.
//
//  Templates and selectors take `inout RandomSource` rather than a generic generator so
//  they stay usable through an `any ProblemTemplate` existential — the registry hands out
//  existentials, and a generic requirement would make them uncallable.

/// A seeded generator, injected everywhere randomness is needed.
public struct RandomSource: RandomNumberGenerator {
    private var generator: any RandomNumberGenerator

    /// The seed this source was created from, carried so a problem can record and replay it.
    public let seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed
        self.generator = SplitMix64(seed: seed)
    }

    /// Wraps a caller-supplied generator. `seed` is recorded for provenance only.
    public init(seed: UInt64, generator: some RandomNumberGenerator) {
        self.seed = seed
        self.generator = generator
    }

    public mutating func next() -> UInt64 {
        generator.next()
    }
}
