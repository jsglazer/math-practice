//  TemplateGolden.swift
//  The frozen fixture schema shared by the SymPy gate and the headless tests.
//
//  `Tools/verify_templates/verify_templates.py` differentiates every record's
//  `canonicalPrompt` with SymPy and refuses to emit the file unless it matches
//  `canonicalAnswer`. The Swift suite then asserts the generators still reproduce the file
//  byte for byte — so `swift test` needs no Python, and a template can only change if the
//  gate is re-run. Goldens are never edited by hand.

/// The seeds and difficulty offsets every template is sampled at.
public enum GoldenSampling {
    /// Fixed seeds. Adding one widens coverage; changing one invalidates the fixture.
    public static let seeds: [UInt64] = [1, 7, 4242]

    /// The difficulties sampled inside a template's own band: bottom, middle, top.
    public static func difficulties(for range: ClosedRange<Int>) -> [Int] {
        let low = range.lowerBound
        let high = range.upperBound
        let middle = low + (high - low) / 2
        return Array(Set([low, middle, high])).sorted()
    }
}

/// The whole fixture file.
public struct GoldenFixture: Hashable, Sendable, Codable {
    /// Bumped whenever the record shape changes, so a stale file fails loudly.
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let seeds: [UInt64]
    public let records: [GeneratedProblem]

    public init(schemaVersion: Int = GoldenFixture.currentSchemaVersion, seeds: [UInt64], records: [GeneratedProblem]) {
        self.schemaVersion = schemaVersion
        self.seeds = seeds
        self.records = records
    }

    /// Generates the full sample set for a registry. The dump tool and the test suite both
    /// call this, so neither can drift from the other.
    public static func sample(registry: TopicRegistry, seeds: [UInt64] = GoldenSampling.seeds) -> GoldenFixture {
        var records: [GeneratedProblem] = []
        for topic in registry.topics {
            for template in topic.templates {
                for difficulty in GoldenSampling.difficulties(for: template.difficultyRange) {
                    for seed in seeds {
                        records.append(template.generate(topicID: topic.id, difficulty: difficulty, seed: seed))
                    }
                }
            }
        }
        return GoldenFixture(seeds: seeds, records: records)
    }
}
