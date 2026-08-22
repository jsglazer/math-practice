//  RevealTests.swift
//  The disclosure policy. This is the interaction the whole app exists to serve, so it is
//  tested as a pure state machine rather than through a view.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Reveal loop")
struct RevealTests {
    let machine = RevealMachine(
        answerLatex: "2x",
        steps: [
            SolutionStep(title: "One", latex: "a", canonical: "a"),
            SolutionStep(title: "Two", latex: "b", canonical: "b"),
            SolutionStep(title: "Three", latex: "c", canonical: "c")
        ]
    )

    @Test("Nothing is disclosed until it is asked for")
    func startsHidden() {
        let state = RevealState()
        #expect(state.answerShown == false)
        #expect(state.stepsShown == 0)
        #expect(machine.visibleSteps(for: state).isEmpty)
    }

    @Test("Asking for the answer reveals exactly the answer")
    func answerReveals() {
        let (state, output) = machine.apply(.answer, to: RevealState())
        #expect(state.answerShown)
        #expect(state.stepsShown == 0)
        #expect(output == .answer(latex: "2x"))
    }

    @Test("Steps come one at a time, in order")
    func stepsComeOneAtATime() {
        var state = RevealState()
        for expected in 1...3 {
            let result = machine.apply(.step, to: state)
            state = result.state
            #expect(state.stepsShown == expected)
            guard case let .step(number, step) = result.output else {
                Issue.record("expected a single step, got \(result.output)")
                return
            }
            #expect(number == expected)
            #expect(step.title == machine.steps[expected - 1].title)
        }
    }

    @Test("Asking past the last step reports there is nothing more")
    func exhaustedSteps() {
        var state = RevealState()
        for _ in 0..<3 { state = machine.apply(.step, to: state).state }

        let result = machine.apply(.step, to: state)
        #expect(result.output == .noFurtherSteps)
        #expect(result.state.stepsShown == 3)
        #expect(result.state.answerShown == false)
    }

    @Test("A step request after the answer releases the whole derivation at once")
    func stepAfterAnswerReleasesEverything() {
        let shown = machine.apply(.answer, to: RevealState()).state
        let result = machine.apply(.step, to: shown)
        #expect(result.output == .allSteps(machine.steps))
        #expect(result.state.stepsShown == 3)
    }

    @Test("Partial steps followed by the answer still release the whole derivation")
    func partialThenAnswer() {
        var state = machine.apply(.step, to: RevealState()).state
        #expect(state.stepsShown == 1)
        state = machine.apply(.answer, to: state).state
        let result = machine.apply(.step, to: state)
        #expect(result.output == .allSteps(machine.steps))
    }

    @Test("Asking for the answer twice is harmless")
    func answerIsIdempotent() {
        let first = machine.apply(.answer, to: RevealState())
        let second = machine.apply(.answer, to: first.state)
        #expect(second.state == first.state)
        #expect(second.output == first.output)
    }

    @Test("The machine is pure — the same state and request always give the same result")
    func machineIsPure() {
        let state = RevealState(answerShown: false, stepsShown: 1)
        let first = machine.apply(.step, to: state)
        let second = machine.apply(.step, to: state)
        #expect(first.state == second.state)
        #expect(first.output == second.output)
    }

    @Test("Visible steps track the state")
    func visibleStepsTrackState() {
        #expect(machine.visibleSteps(for: RevealState(stepsShown: 2)).count == 2)
        #expect(machine.visibleSteps(for: RevealState(stepsShown: 99)).count == 3)
    }

    @Test("A problem with no steps degrades gracefully")
    func emptyStepList() {
        let empty = RevealMachine(answerLatex: "0", steps: [])
        let result = empty.apply(.step, to: RevealState())
        #expect(result.output == .noFurtherSteps)
    }

    @Test("Every generated problem drives the loop to completion")
    func realProblemsRevealFully() throws {
        let selector = ProblemSelector(registry: .standard)
        var generator = RandomSource(seed: 404)
        let request = PracticeRequest(topic: .derivatives, subType: nil, difficulty: .fixed(7))

        for _ in 0..<30 {
            let problem = try selector.next(request, ladder: DifficultyLadder.fold([]), using: &generator)
            let machine = RevealMachine(problem: problem)
            var state = RevealState()
            for expected in 1...problem.steps.count {
                let result = machine.apply(.step, to: state)
                state = result.state
                #expect(state.stepsShown == expected)
            }
            #expect(machine.apply(.step, to: state).output == .noFurtherSteps)
            #expect(machine.apply(.answer, to: state).output == .answer(latex: problem.answerLatex))
        }
    }
}
