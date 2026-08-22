//  DeterminismTests.swift
//  Generation is seeded end to end. If any of this drifts, the golden fixtures are worth
//  nothing and every other suite becomes flaky.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Seeded determinism")
struct DeterminismTests {
    @Test("SplitMix64 reproduces its sequence from a seed")
    func generatorIsReproducible() {
        var first = SplitMix64(seed: 12345)
        var second = SplitMix64(seed: 12345)
        let a = (0..<64).map { _ in first.next() }
        let b = (0..<64).map { _ in second.next() }
        #expect(a == b)
    }

    @Test("Different seeds diverge")
    func seedsDiverge() {
        var first = SplitMix64(seed: 1)
        var second = SplitMix64(seed: 2)
        #expect((0..<16).map { _ in first.next() } != (0..<16).map { _ in second.next() })
    }

    @Test("SplitMix64 matches the reference vector for seed 0")
    func matchesReferenceVector() {
        // The published SplitMix64 outputs for seed 0 — a canary against an accidental
        // constant or shift edit silently invalidating every checked-in golden.
        var generator = SplitMix64(seed: 0)
        let expected: [UInt64] = [
            0xE220A8397B1DCDAF,
            0x6E789E6AA1B965F4,
            0x06C45D188009454F
        ]
        #expect((0..<3).map { _ in generator.next() } == expected)
    }

    @Test("Draws stay inside their range")
    func drawsRespectBounds() {
        var generator = RandomSource(seed: 4)
        for _ in 0..<2_000 {
            let value = generator.drawInt(in: -7...11)
            #expect((-7...11).contains(value))
        }
    }

    @Test("Non-zero draws never return zero")
    func nonZeroDraws() {
        var generator = RandomSource(seed: 8)
        for _ in 0..<2_000 {
            #expect(generator.drawNonZeroInt(in: -3...3) != 0)
        }
    }

    @Test("A single-value range is honoured")
    func singleValueRange() {
        var generator = RandomSource(seed: 1)
        #expect(generator.drawInt(in: 5...5) == 5)
    }

    @Test("Draws are uniform enough to exercise every branch")
    func drawsCoverTheRange() {
        var generator = RandomSource(seed: 2024)
        var seen: Set<Int> = []
        for _ in 0..<5_000 {
            seen.insert(generator.drawInt(in: 1...10))
        }
        #expect(seen == Set(1...10))
    }

    @Test("The shuffle is deterministic and preserves the multiset")
    func shuffleIsDeterministic() {
        let input = Array(1...20)
        var first = RandomSource(seed: 55)
        var second = RandomSource(seed: 55)
        let a = first.drawShuffled(input)
        let b = second.drawShuffled(input)
        #expect(a == b)
        #expect(a.sorted() == input)
        #expect(a != input)
    }

    @Test(
        "A template regenerates byte-for-byte from its seed",
        arguments: TopicRegistry.standard.topics.flatMap(\.templates).map(\.id)
    )
    func templatesReproduceFromSeed(templateID: TemplateID) throws {
        let resolved = try #require(TopicRegistry.standard.resolve(templateID))
        for seed in GoldenSampling.seeds {
            let difficulty = resolved.template.difficultyRange.lowerBound
            let first = resolved.template.generate(topicID: resolved.topic.id, difficulty: difficulty, seed: seed)
            let second = resolved.template.generate(topicID: resolved.topic.id, difficulty: difficulty, seed: seed)
            #expect(first == second)
            #expect(first.seed == seed)
        }
    }

    @Test("A whole session replays from one seed")
    func sessionsReplay() throws {
        let selector = ProblemSelector(registry: .standard)
        let request = PracticeRequest(topic: .derivatives, subType: nil, difficulty: .fixed(6))
        let ladder = DifficultyLadder.fold([])

        func session() throws -> [GeneratedProblem] {
            var generator = RandomSource(seed: 0xDEC1_5104)
            return try (0..<25).map { _ in try selector.next(request, ladder: ladder, using: &generator) }
        }

        #expect(try session() == (try session()))
    }

    @Test("A generated problem never lands outside 1...10")
    func difficultyStaysInBounds() throws {
        let selector = ProblemSelector(registry: .standard)
        var generator = RandomSource(seed: 31)
        for level in -5...20 {
            let request = PracticeRequest(topic: .derivatives, subType: nil, difficulty: .fixed(level))
            let problem = try selector.next(request, ladder: DifficultyLadder.fold([]), using: &generator)
            #expect(DifficultyLadder.bounds.contains(problem.difficulty))
        }
    }
}
