//  TopicRegistryTests.swift
//  Deterministic test requirement: new topic modules can be registered and resolved via a
//  TopicRegistry without altering core models.
//
//  The proof is `TestTopic` — a topic defined entirely in the test target, which
//  MathPracticeCore has never heard of. If it can drive the selector, the router, the
//  ladder and the dashboard unchanged, then adding integrals is one directory plus one
//  line in `TopicRegistry.standard`.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Topic registry and extensibility")
struct TopicRegistryTests {
    let registry = TopicRegistry(topics: [TestTopic()])
    let doublingKey = PracticeKey(topic: .testTopic, subType: .testDoubling)
    let squaringKey = PracticeKey(topic: .testTopic, subType: .testSquaring)

    // MARK: - Registration and resolution

    @Test("A topic the core has never heard of registers and resolves")
    func registersUnknownTopic() {
        #expect(registry.topic(.testTopic)?.displayName == "Test Topic")
        #expect(registry.topic(.derivatives) == nil)
    }

    @Test("Templates resolve back to their owning topic")
    func resolvesTemplates() {
        let resolved = registry.resolve(TemplateID("test-topic.squaring.quadratic"))
        #expect(resolved?.topic.id == .testTopic)
        #expect(resolved?.template.subTypeID == .testSquaring)
        #expect(registry.resolve(TemplateID("nope")) == nil)
    }

    @Test("Practice keys come out of the topic, not a hardcoded list")
    func practiceKeysAreDerived() {
        #expect(registry.practiceKeys == [doublingKey, squaringKey])
    }

    @Test("Display names route through the registry")
    func displayNamesRoute() {
        #expect(registry.displayName(for: doublingKey) == "Test Topic · Doubling")
    }

    @Test("The shipping registry holds exactly the derivatives topic")
    func standardRegistry() {
        #expect(TopicRegistry.standard.topics.count == 1)
        #expect(TopicRegistry.standard.topic(.derivatives) != nil)
        #expect(TopicRegistry.standard.practiceKeys.count == 7)
    }

    // MARK: - Driving the selector through the fake topic

    @Test("The selector poses problems from an unknown topic")
    func selectorServesUnknownTopic() throws {
        let selector = ProblemSelector(registry: registry)
        var generator = RandomSource(seed: 11)
        let request = PracticeRequest(topic: .testTopic, subType: .testDoubling, difficulty: .fixed(5))

        let problem = try selector.next(request, ladder: DifficultyLadder.fold([]), using: &generator)
        #expect(problem.topicID == .testTopic)
        #expect(problem.subTypeID == .testDoubling)
        #expect(problem.difficulty == 5)
        #expect(problem.instruction == "Double the coefficient")
    }

    @Test("A nil sub-type mixes across the topic's sub-types")
    func selectorMixesSubTypes() throws {
        let selector = ProblemSelector(registry: registry)
        var generator = RandomSource(seed: 3)
        let request = PracticeRequest(topic: .testTopic, subType: nil, difficulty: .fixed(8))

        var seen: Set<SubTypeID> = []
        for _ in 0..<40 {
            let problem = try selector.next(request, ladder: DifficultyLadder.fold([]), using: &generator)
            seen.insert(problem.subTypeID)
        }
        #expect(seen == [.testDoubling, .testSquaring])
    }

    @Test("A nil topic mixes across every registered topic")
    func selectorMixesTopics() throws {
        let mixed = TopicRegistry(topics: [TestTopic(), DerivativesTopic()])
        let selector = ProblemSelector(registry: mixed)
        var generator = RandomSource(seed: 5)
        let request = PracticeRequest(topic: nil, subType: nil, difficulty: .fixed(6))

        var seen: Set<TopicID> = []
        for _ in 0..<60 {
            let problem = try selector.next(request, ladder: DifficultyLadder.fold([]), using: &generator)
            seen.insert(problem.topicID)
        }
        #expect(seen == [.testTopic, .derivatives])
    }

    @Test("Adaptive difficulty reads the ladder for the selected key")
    func selectorFollowsTheLadder() throws {
        let selector = ProblemSelector(registry: registry)
        let events = EventFactory.run(Array(repeating: .c, count: 9), key: doublingKey)
        let ladder = DifficultyLadder.fold(events)
        var generator = RandomSource(seed: 21)
        let request = PracticeRequest(topic: .testTopic, subType: .testDoubling, difficulty: .adaptive)

        let problem = try selector.next(request, ladder: ladder, using: &generator)
        #expect(problem.difficulty == 4)
    }

    @Test("A difficulty below a sub-type's band falls back to its nearest template")
    func selectorFallsBackToNearestBand() throws {
        let selector = ProblemSelector(registry: registry)
        var generator = RandomSource(seed: 2)
        // Squaring starts at difficulty 4; asking for 1 must still pose a problem.
        let request = PracticeRequest(topic: .testTopic, subType: .testSquaring, difficulty: .fixed(1))

        let problem = try selector.next(request, ladder: DifficultyLadder.fold([]), using: &generator)
        #expect(problem.subTypeID == .testSquaring)
    }

    @Test("An unknown topic is refused rather than silently substituted")
    func selectorRefusesUnknownTopic() {
        let selector = ProblemSelector(registry: registry)
        var generator = RandomSource(seed: 1)
        let request = PracticeRequest(topic: .derivatives, subType: nil, difficulty: .fixed(1))

        #expect(throws: SelectionFailure.unknownTopic(.derivatives)) {
            try selector.next(request, ladder: DifficultyLadder.fold([]), using: &generator)
        }
    }

    // MARK: - Driving the ladder and dashboard through the fake topic

    @Test("The ladder tracks an unknown topic's keys with no core change")
    func ladderTracksUnknownTopic() {
        var events = EventFactory.run(Array(repeating: .c, count: 6), key: doublingKey)
        events += EventFactory.run([.w, .w], key: squaringKey, firstOrdinal: events.count)

        let snapshot = DifficultyLadder.fold(events)
        #expect(snapshot.level(for: doublingKey) == 3)
        #expect(snapshot.level(for: squaringKey) == 1)
    }

    @Test("The dashboard aggregates an unknown topic's keys")
    func dashboardAggregatesUnknownTopic() throws {
        var events = EventFactory.run([.c, .c, .w], key: doublingKey, difficulty: 2)
        events += EventFactory.run([.c, .w], key: doublingKey, difficulty: 5, firstOrdinal: events.count)
        events += EventFactory.run([.c], key: squaringKey, difficulty: 5, firstOrdinal: events.count)

        let matrix = DashboardAggregator.aggregate(
            events: events,
            keys: registry.practiceKeys,
            ladder: DifficultyLadder.fold(events)
        )

        #expect(matrix.difficulties == [2, 5])
        #expect(matrix.rows.count == 2)

        let doubling = try #require(matrix.row(for: doublingKey))
        #expect(doubling.attempts == 5)
        #expect(doubling.correct == 3)
        #expect(doubling.cell(atDifficulty: 2)?.attempts == 3)
        #expect(doubling.cell(atDifficulty: 5)?.correct == 1)

        let squaring = try #require(matrix.row(for: squaringKey))
        #expect(squaring.attempts == 1)
        #expect(squaring.cell(atDifficulty: 2)?.attempts == 0)
        #expect(matrix.totalAttempts == 6)
    }

    @Test("A key with no attempts still appears as an empty row")
    func dashboardShowsUntouchedKeys() {
        let matrix = DashboardAggregator.aggregate(
            events: [],
            keys: registry.practiceKeys,
            ladder: DifficultyLadder.fold([])
        )
        #expect(matrix.rows.count == 2)
        #expect(matrix.rows.allSatisfy { $0.attempts == 0 })
        #expect(matrix.rows.allSatisfy { $0.accuracy == nil })
        #expect(matrix.rows.allSatisfy { $0.currentLevel == 1 })
    }

    @Test("Nothing in core hardcodes derivatives as the only topic")
    func coreDoesNotAssumeDerivatives() throws {
        // The whole pipeline — select, reveal, record, fold, aggregate — driven end to end
        // by a topic that exists only in this test target.
        let selector = ProblemSelector(registry: registry)
        var generator = RandomSource(seed: 77)
        var events: [PracticeEvent] = []

        for ordinal in 0..<9 {
            let ladder = DifficultyLadder.fold(events)
            let request = PracticeRequest(topic: .testTopic, subType: .testDoubling, difficulty: .adaptive)
            let problem = try selector.next(request, ladder: ladder, using: &generator)

            let machine = RevealMachine(problem: problem)
            let (state, output) = machine.apply(.step, to: RevealState())
            #expect(state.stepsShown == 1)
            if case .step(let number, _) = output {
                #expect(number == 1)
            } else {
                Issue.record("expected a single step, got \(output)")
            }

            events.append(EventFactory.attempt(
                .correct,
                key: problem.practiceKey,
                difficulty: problem.difficulty,
                ordinal: ordinal
            ))
        }

        let ladder = DifficultyLadder.fold(events)
        #expect(ladder.level(for: doublingKey) == 4)

        let matrix = DashboardAggregator.aggregate(events: events, keys: registry.practiceKeys, ladder: ladder)
        #expect(matrix.totalAttempts == 9)
        #expect(matrix.totalCorrect == 9)
    }
}
