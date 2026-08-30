//  PresentationTests.swift
//  The prose half of a template — its instruction and its step titles — checked
//  mechanically, because both have shipped wrong before and neither is covered by the
//  SymPy gate (which only ever looks at the maths).
//
//  Update007 reworded the partial-derivative instructions and turned "Find ∂f/∂x, treating
//  y as a constant" into "Find ∂f/∂x, with respect to y" — the held variable got
//  substituted into the phrase that names the differentiation variable, which inverts the
//  question. `instructionsNameOnlyTheirOwnVariable` is the check that would have caught it:
//  it reads the instruction against the template's own `verificationRule`, which is what
//  the answer is actually verified against, so the two cannot disagree silently again.
//
//  `stepTitlesTypesetTheirMaths` covers the other half: step titles are prose, rendered as
//  prose, so any LaTeX in them has to sit inside `$…$` (the same inline-math delimiter the
//  Markdown view uses) or it reaches the screen as raw `x^{3} y^{3}`.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Instruction and step-title presentation")
struct PresentationTests {
    /// Every shipping template, generated across its whole difficulty band on a fixed seed
    /// set — enough coverage that a title interpolating an expression is always exercised.
    static let problems: [GeneratedProblem] = {
        var generated: [GeneratedProblem] = []
        for topic in TopicRegistry.standard.topics {
            for template in topic.templates {
                for difficulty in template.difficultyRange {
                    for seed in GoldenSampling.seeds {
                        generated.append(
                            template.generate(topicID: topic.id, difficulty: difficulty, seed: seed)
                        )
                    }
                }
            }
        }
        return generated
    }()

    // MARK: - Instructions

    @Test("A partial-derivative instruction names only the variable it is differentiated by")
    func instructionsNameOnlyTheirOwnVariable() {
        for topic in TopicRegistry.standard.topics {
            for template in topic.templates {
                let instruction = template.instruction
                let id = template.id.rawValue

                switch template.verificationRule {
                case .partialDerivativeX:
                    #expect(instruction.contains("∂f/∂x"), "\(id): must ask for ∂f/∂x")
                    #expect(!instruction.contains("∂f/∂y"), "\(id): asks for ∂f/∂y as well")
                    // "with respect to y" on a ∂/∂x template is the Update007 inversion.
                    #expect(
                        !instruction.lowercased().contains("respect to y"),
                        "\(id): '\(instruction)' names y as the variable differentiated by"
                    )
                case .partialDerivativeY:
                    #expect(instruction.contains("∂f/∂y"), "\(id): must ask for ∂f/∂y")
                    #expect(!instruction.contains("∂f/∂x"), "\(id): asks for ∂f/∂x as well")
                    #expect(
                        !instruction.lowercased().contains("respect to x"),
                        "\(id): '\(instruction)' names x as the variable differentiated by"
                    )
                case .derivative:
                    #expect(
                        !instruction.contains("∂"),
                        "\(id): an ordinary derivative should not be posed with ∂"
                    )
                }
            }
        }
    }

    @Test("Every template states an instruction")
    func instructionsArePresent() {
        for problem in Self.problems {
            #expect(!problem.instruction.isEmpty, "\(problem.templateID.rawValue): blank instruction")
        }
    }

    // MARK: - Step titles

    /// Characters that only ever appear in a title because LaTeX leaked into the prose.
    /// `$` is excluded — it is the delimiter itself — and so is `'` (as in `g'`), which is
    /// an ordinary apostrophe on screen.
    static let latexOnlyCharacters = Set("\\^_{}")

    @Test("Step titles keep their maths inside $…$ so it is typeset, not printed raw")
    func stepTitlesTypesetTheirMaths() {
        for problem in Self.problems {
            for (index, step) in problem.steps.enumerated() {
                let where_ = "\(problem.templateID.rawValue) step \(index + 1): '\(step.title)'"
                let pieces = step.title.components(separatedBy: "$")

                #expect(pieces.count % 2 == 1, "\(where_) has an unmatched $")

                // Even indices are the prose between the math spans.
                for prose in stride(from: 0, to: pieces.count, by: 2).map({ pieces[$0] }) {
                    let leaked = prose.filter(Self.latexOnlyCharacters.contains)
                    #expect(
                        leaked.isEmpty,
                        "\(where_) prints LaTeX '\(leaked)' outside $…$, so it renders raw"
                    )
                }
                // And a math span with nothing in it would render as an empty box.
                for math in stride(from: 1, to: pieces.count, by: 2).map({ pieces[$0] }) {
                    #expect(!math.isEmpty, "\(where_) has an empty $$ span")
                }
            }
        }
    }

    @Test("Every step carries a title and something to typeset")
    func stepsAreComplete() {
        for problem in Self.problems {
            #expect(!problem.steps.isEmpty, "\(problem.templateID.rawValue): no worked steps")
            for step in problem.steps {
                #expect(!step.title.isEmpty)
                #expect(!step.latex.isEmpty)
            }
        }
    }
}
