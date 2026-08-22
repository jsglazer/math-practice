//  GoldenFixtureTests.swift
//  The Swift half of the SymPy gate.
//
//  `Tools/verify_templates/verify_templates.py` differentiates every record with SymPy and
//  only writes the fixture when the templates' stated answers check out. This suite asserts
//  the generators still reproduce that file exactly — so a template cannot change without
//  the gate being re-run, and `swift test` needs no Python at all.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Golden fixtures")
struct GoldenFixtureTests {
    /// Loads the checked-in fixture from the test bundle. No network, no shelling out.
    static func loadFixture() throws -> GoldenFixture {
        let url = try #require(
            Bundle.module.url(forResource: "templates", withExtension: "json", subdirectory: "Golden"),
            "Golden/templates.json is missing — regenerate it with Tools/verify_templates"
        )
        return try JSONDecoder().decode(GoldenFixture.self, from: Data(contentsOf: url))
    }

    @Test("The fixture is present and matches the current schema")
    func fixtureLoads() throws {
        let fixture = try Self.loadFixture()
        #expect(fixture.schemaVersion == GoldenFixture.currentSchemaVersion)
        #expect(fixture.seeds == GoldenSampling.seeds)
        #expect(!fixture.records.isEmpty)
    }

    @Test("Every generator reproduces its SymPy-verified golden exactly")
    func generatorsMatchGoldens() throws {
        let fixture = try Self.loadFixture()
        let registry = TopicRegistry.standard

        for golden in fixture.records {
            let resolved = try #require(
                registry.resolve(golden.templateID),
                "golden references template '\(golden.templateID)' that no topic owns"
            )
            let regenerated = resolved.template.generate(
                topicID: resolved.topic.id,
                difficulty: golden.difficulty,
                seed: golden.seed
            )
            let sample = "difficulty \(golden.difficulty), seed \(golden.seed)"
            #expect(
                regenerated == golden,
                "template '\(golden.templateID)' at \(sample) drifted from its golden"
            )
        }
    }

    @Test("The sampled set is exactly the fixture's set — no template escaped the gate")
    func samplingCoversEveryTemplate() throws {
        let fixture = try Self.loadFixture()
        let sampled = GoldenFixture.sample(registry: .standard)
        #expect(sampled.records == fixture.records)

        let goldenTemplates = Set(fixture.records.map(\.templateID))
        let registryTemplates = Set(TopicRegistry.standard.topics.flatMap(\.templates).map(\.id))
        #expect(goldenTemplates == registryTemplates)
    }

    @Test("Every golden carries both renderings and a worked derivation")
    func goldensAreComplete() throws {
        for golden in try Self.loadFixture().records {
            #expect(!golden.promptLatex.isEmpty)
            #expect(!golden.answerLatex.isEmpty)
            #expect(!golden.canonicalPrompt.isEmpty)
            #expect(!golden.canonicalAnswer.isEmpty)
            #expect(golden.steps.count >= 2, "\(golden.templateID) has too few steps")
            #expect(golden.steps.contains { $0.canonical != nil })
            #expect(golden.steps.allSatisfy { !$0.title.isEmpty && !$0.latex.isEmpty })
        }
    }

    @Test("The last stated step lands on the answer")
    func finalStepMatchesAnswer() throws {
        for golden in try Self.loadFixture().records {
            let stated = golden.steps.compactMap(\.canonical)
            let final = try #require(stated.last, "\(golden.templateID) states no expression")
            #expect(final == golden.canonicalAnswer, "\(golden.templateID)'s derivation ends elsewhere")
        }
    }

    @Test("Every template is sampled at the bottom, middle and top of its band")
    func samplingHitsEachBand() throws {
        let fixture = try Self.loadFixture()
        for template in TopicRegistry.standard.topics.flatMap(\.templates) {
            let expected = Set(GoldenSampling.difficulties(for: template.difficultyRange))
            let sampled = Set(fixture.records.filter { $0.templateID == template.id }.map(\.difficulty))
            #expect(sampled == expected, "\(template.id) is under-sampled")
        }
    }
}
