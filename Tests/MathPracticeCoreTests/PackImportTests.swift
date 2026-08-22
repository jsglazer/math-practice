//  PackImportTests.swift
//  LLM-authored problem packs: wholesale validation, and (identifier, version) semantics.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Problem pack import")
struct PackImportTests {
    let registry = TopicRegistry.standard

    func makeProblem(
        index: Int,
        difficulty: Int = 5,
        subType: SubTypeID = .chainRule
    ) -> PackProblem {
        PackProblem(
            index: index,
            subTypeID: subType,
            difficulty: difficulty,
            instruction: "Differentiate with respect to x",
            promptLatex: "\\sin\\left(x^{2}\\right)",
            answerLatex: "2 x \\cos\\left(x^{2}\\right)",
            steps: [
                .narrative("Apply the chain rule", latex: "f'(g)g'"),
                SolutionStep(
                    title: "Substitute",
                    latex: "2 x \\cos\\left(x^{2}\\right)",
                    canonical: "(2*x*cos((x)**(2)))"
                )
            ],
            canonicalPrompt: "sin((x)**(2))",
            canonicalAnswer: "(2*x*cos((x)**(2)))"
        )
    }

    func makePack(
        identifier: String = "llm-chain",
        version: Int = 1,
        problems: [PackProblem]? = nil
    ) -> ProblemPack {
        ProblemPack(
            identifier: identifier,
            version: version,
            title: "Chain rule, LLM authored",
            topicID: .derivatives,
            problems: problems ?? (0..<3).map { makeProblem(index: $0) }
        )
    }

    // MARK: - Validation

    @Test("A well-formed pack validates")
    func validPackPasses() throws {
        let result = PackValidator.validate(makePack(), registry: registry)
        let validated = try #require(try? result.get())
        #expect(validated.pack.problems.count == 3)
    }

    @Test("A validated pack becomes ordinary problems the rest of the app cannot distinguish")
    func validatedPackYieldsProblems() throws {
        let validated = try PackValidator.validate(makePack(), registry: registry).get()
        let problems = validated.problems()
        #expect(problems.count == 3)
        #expect(problems[0].topicID == .derivatives)
        #expect(problems[0].subTypeID == .chainRule)
        #expect(problems[0].practiceKey == PracticeKey(topic: .derivatives, subType: .chainRule))
        #expect(problems[0].templateID.rawValue == "pack:llm-chain:1:0")
    }

    @Test("A pack with one bad problem is rejected in full, never partially imported")
    func rejectionIsWholesale() {
        var problems = (0..<3).map { makeProblem(index: $0) }
        problems[1] = PackProblem(
            index: 1,
            subTypeID: .chainRule,
            difficulty: 42,
            instruction: "Differentiate",
            promptLatex: "x",
            answerLatex: "1",
            steps: [SolutionStep(title: "Done", latex: "1", canonical: "1")],
            canonicalPrompt: "x",
            canonicalAnswer: "1"
        )

        let result = PackValidator.validate(makePack(problems: problems), registry: registry)
        guard case let .failure(failure) = result else {
            Issue.record("expected the pack to be rejected")
            return
        }
        #expect(failure.errors.contains(.difficultyOutOfRange(index: 1, difficulty: 42)))
    }

    @Test("Every reason for rejection is reported at once")
    func allErrorsReported() {
        let pack = ProblemPack(
            identifier: "  ",
            version: 0,
            title: "",
            topicID: TopicID("nope"),
            problems: []
        )
        guard case let .failure(failure) = PackValidator.validate(pack, registry: registry) else {
            Issue.record("expected the pack to be rejected")
            return
        }
        #expect(failure.errors.contains(.emptyIdentifier))
        #expect(failure.errors.contains(.nonPositiveVersion(0)))
        #expect(failure.errors.contains(.emptyTitle))
        #expect(failure.errors.contains(.unknownTopic(TopicID("nope"))))
        #expect(failure.errors.contains(.noProblems))
    }

    @Test("An unknown sub-type is rejected")
    func unknownSubTypeRejected() {
        let pack = makePack(problems: [makeProblem(index: 0, subType: SubTypeID("integration-by-parts"))])
        guard case let .failure(failure) = PackValidator.validate(pack, registry: registry) else {
            Issue.record("expected the pack to be rejected")
            return
        }
        #expect(failure.errors.contains(.unknownSubType(index: 0, subType: SubTypeID("integration-by-parts"))))
    }

    @Test("Out-of-order indices are rejected, because they are the dedupe identity")
    func indexOrderMatters() {
        let pack = makePack(problems: [makeProblem(index: 0), makeProblem(index: 5)])
        guard case let .failure(failure) = PackValidator.validate(pack, registry: registry) else {
            Issue.record("expected the pack to be rejected")
            return
        }
        #expect(failure.errors.contains(.indexOutOfOrder(expected: 1, found: 5)))
    }

    @Test("Empty fields and stepless problems are rejected")
    func emptyFieldsRejected() {
        let problem = PackProblem(
            index: 0,
            subTypeID: .chainRule,
            difficulty: 3,
            instruction: "Differentiate",
            promptLatex: "  ",
            answerLatex: "1",
            steps: [],
            canonicalPrompt: "x",
            canonicalAnswer: "1"
        )
        let result = PackValidator.validate(makePack(problems: [problem]), registry: registry)
        guard case let .failure(failure) = result else {
            Issue.record("expected the pack to be rejected")
            return
        }
        #expect(failure.errors.contains(.emptyField(index: 0, field: "promptLatex")))
        #expect(failure.errors.contains(.noSteps(index: 0)))
    }

    // MARK: - Import planning

    @Test("A pack nobody has seen installs")
    func newPackInstalls() {
        #expect(PackImportPlanner.plan(candidate: makePack(), installed: []) == .install)
    }

    @Test("Re-importing the same identifier and version is a no-op")
    func reimportIsNoOp() {
        let installed = [InstalledPack(identifier: "llm-chain", version: 1, isHidden: false)]
        #expect(
            PackImportPlanner.plan(candidate: makePack(version: 1), installed: installed)
                == .noOp(identifier: "llm-chain", version: 1)
        )
    }

    @Test("A higher version supersedes and hides the earlier one")
    func higherVersionSupersedes() {
        let installed = [
            InstalledPack(identifier: "llm-chain", version: 1, isHidden: false),
            InstalledPack(identifier: "llm-chain", version: 2, isHidden: false)
        ]
        #expect(
            PackImportPlanner.plan(candidate: makePack(version: 3), installed: installed)
                == .supersede(hiding: [1, 2])
        )
    }

    @Test("Superseding never deletes — attempt history still references the old version")
    func supersedeOnlyHides() {
        let installed = [InstalledPack(identifier: "llm-chain", version: 1, isHidden: true)]
        // Already hidden, so there is nothing further to hide — and nothing to delete.
        #expect(
            PackImportPlanner.plan(candidate: makePack(version: 2), installed: installed)
                == .supersede(hiding: [])
        )
    }

    @Test("An older version is refused rather than silently regressing the library")
    func olderVersionRefused() {
        let installed = [InstalledPack(identifier: "llm-chain", version: 4, isHidden: false)]
        #expect(
            PackImportPlanner.plan(candidate: makePack(version: 2), installed: installed)
                == .supersededByNewer(installedVersion: 4)
        )
    }

    @Test("A different identifier is unaffected by what else is installed")
    func identifiersAreIndependent() {
        let installed = [InstalledPack(identifier: "other-pack", version: 9, isHidden: false)]
        #expect(PackImportPlanner.plan(candidate: makePack(), installed: installed) == .install)
    }

    // MARK: - Round trip

    @Test("A pack round-trips through JSON with the same schema the goldens use")
    func packRoundTrips() throws {
        let pack = makePack()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(pack)
        let decoded = try JSONDecoder().decode(ProblemPack.self, from: data)
        #expect(decoded == pack)

        // The identifiers encode as plain strings, exactly as the golden fixture does.
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"topicID\":\"derivatives\""))
        #expect(text.contains("\"subTypeID\":\"chain\""))
    }
}
