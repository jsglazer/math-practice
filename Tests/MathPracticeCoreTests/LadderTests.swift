//  LadderTests.swift
//  Deterministic test requirement: the adaptive difficulty ladder's transitions for
//  levels 1-10, across multiple success/failure sequences.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Adaptive difficulty ladder")
struct LadderTests {
    let key = PracticeKey(topic: .derivatives, subType: .powerRule)

    // MARK: - Climbing

    @Test("An unseen key starts at level 1")
    func startsAtBottom() {
        let snapshot = DifficultyLadder.fold([])
        #expect(snapshot.level(for: key) == 1)
    }

    @Test("Three consecutive successes step up one level")
    func stepsUpOnThreshold() {
        let events = EventFactory.run([.c, .c, .c], key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 2)
    }

    @Test("Two successes are not enough to step up")
    func doesNotStepUpEarly() {
        let events = EventFactory.run([.c, .c], key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 1)
    }

    @Test("A failure resets the success run")
    func failureResetsSuccessRun() {
        let events = EventFactory.run([.c, .c, .w, .c, .c], key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 1)
    }

    @Test("Climbing every rung from 1 to 10 takes 27 successes")
    func climbsToCeiling() {
        let events = EventFactory.run(Array(repeating: .c, count: 27), key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 10)
    }

    @Test("Level 10 is a ceiling, not a wrap-around")
    func clampsAtCeiling() {
        let events = EventFactory.run(Array(repeating: .c, count: 90), key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 10)
    }

    /// Walks the whole ladder, asserting the level after each rung's worth of successes.
    @Test("Each level is reached in turn on the way up", arguments: Array(1...10))
    func reachesEachLevelInTurn(level: Int) {
        let successes = (level - 1) * LadderConfiguration.default.stepUpThreshold
        let events = EventFactory.run(Array(repeating: .c, count: successes), key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == level)
    }

    // MARK: - Descending

    @Test("Two consecutive failures step down one level")
    func stepsDownOnThreshold() {
        var events = EventFactory.run(Array(repeating: .c, count: 6), key: key)
        events += EventFactory.run([.w, .w], key: key, firstOrdinal: events.count)
        #expect(DifficultyLadder.level(for: key, in: events) == 2)
    }

    @Test("Level 1 is a floor")
    func clampsAtFloor() {
        let events = EventFactory.run(Array(repeating: .w, count: 20), key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 1)
    }

    @Test("The hold period blocks a second step down until it elapses")
    func holdPeriodBlocksSecondStepDown() {
        // Climb to 4, then fail continuously. Without the hold, 7 failures would take the
        // level to 1; with a 2-attempt hold after each step down, it only reaches 2.
        var events = EventFactory.run(Array(repeating: .c, count: 9), key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 4)

        events += EventFactory.run(Array(repeating: .w, count: 4), key: key, firstOrdinal: events.count)
        #expect(DifficultyLadder.level(for: key, in: events) == 3)

        events += EventFactory.run(Array(repeating: .w, count: 3), key: key, firstOrdinal: events.count)
        #expect(DifficultyLadder.level(for: key, in: events) == 2)
    }

    @Test("Bottoming out does not arm the hold")
    func floorDoesNotArmHold() {
        let events = EventFactory.run([.w, .w, .w, .w], key: key)
        let state = DifficultyLadder.fold(events).state(for: key)
        #expect(state.level == 1)
        #expect(state.holdRemaining == 0)
    }

    // MARK: - Mixed sequences

    @Test("A mixed sequence lands where hand-tracing says it should")
    func mixedSequence() {
        // 3 up -> level 2; w,w down -> level 1 (hold 2); c,c,c up -> level 2.
        let outcomes: [AttemptOutcome] = [.c, .c, .c, .w, .w, .c, .c, .c]
        let events = EventFactory.run(outcomes, key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 2)
    }

    @Test("Alternating right and wrong never moves the level")
    func alternatingIsStable() {
        let outcomes: [AttemptOutcome] = Array(repeating: [.c, .w], count: 20).flatMap(\.self)
        let events = EventFactory.run(outcomes, key: key)
        #expect(DifficultyLadder.level(for: key, in: events) == 1)
    }

    // MARK: - Per-key isolation

    @Test("The ladder is tracked per (topic, sub-type), never globally")
    func laddersAreIndependent() {
        let chain = PracticeKey(topic: .derivatives, subType: .chainRule)
        var events = EventFactory.run(Array(repeating: .c, count: 9), key: key)
        events += EventFactory.run(Array(repeating: .w, count: 4), key: chain, firstOrdinal: events.count)

        let snapshot = DifficultyLadder.fold(events)
        #expect(snapshot.level(for: key) == 4)
        #expect(snapshot.level(for: chain) == 1)
    }

    // MARK: - Configuration and overrides as events

    @Test("A configuration event changes the thresholds from that point forward")
    func configurationIsEventSourced() {
        var events: [PracticeEvent] = [
            EventFactory.configuration(
                LadderConfiguration(stepUpThreshold: 2, stepDownThreshold: 3, holdPeriod: 0),
                ordinal: 0
            )
        ]
        events += EventFactory.run([.c, .c], key: key, firstOrdinal: 1)
        #expect(DifficultyLadder.level(for: key, in: events) == 2)
        #expect(DifficultyLadder.configuration(in: events).stepUpThreshold == 2)
    }

    @Test("The latest configuration event wins")
    func latestConfigurationWins() {
        let events: [PracticeEvent] = [
            EventFactory.configuration(
                LadderConfiguration(stepUpThreshold: 2, stepDownThreshold: 2, holdPeriod: 0),
                ordinal: 0
            ),
            EventFactory.configuration(
                LadderConfiguration(stepUpThreshold: 5, stepDownThreshold: 4, holdPeriod: 1),
                ordinal: 1
            )
        ]
        let resolved = DifficultyLadder.configuration(in: events)
        #expect(resolved.stepUpThreshold == 5)
        #expect(resolved.stepDownThreshold == 4)
        #expect(resolved.holdPeriod == 1)
    }

    @Test("A manual override pins the level and clears the counters")
    func manualOverridePins() {
        var events = EventFactory.run([.c, .c], key: key)
        events.append(EventFactory.override(level: 8, key: key, ordinal: events.count))

        let state = DifficultyLadder.fold(events).state(for: key)
        #expect(state.level == 8)
        #expect(state.consecutiveSuccesses == 0)
    }

    @Test("A manual override is clamped into 1...10")
    func manualOverrideIsClamped() {
        let high = [EventFactory.override(level: 99, key: key, ordinal: 0)]
        let low = [EventFactory.override(level: -4, key: key, ordinal: 0)]
        #expect(DifficultyLadder.level(for: key, in: high) == 10)
        #expect(DifficultyLadder.level(for: key, in: low) == 1)
    }

    // MARK: - Order independence

    @Test("The fold is order-independent: shuffling the input changes nothing")
    func foldIsOrderIndependent() {
        var events = EventFactory.run([.c, .c, .c, .w, .w, .c, .c, .c, .c, .w], key: key)
        events.append(EventFactory.configuration(
            LadderConfiguration(stepUpThreshold: 2, stepDownThreshold: 2, holdPeriod: 1),
            ordinal: 100,
            secondsOffset: -1
        ))
        let expected = DifficultyLadder.fold(events)

        // Every rotation is a different arrival order for the same set of events.
        for rotation in 0..<events.count {
            let rotated = Array(events[rotation...] + events[..<rotation])
            #expect(DifficultyLadder.fold(rotated).states == expected.states)
        }

        // And a seeded shuffle, for an order no rotation produces.
        var generator = RandomSource(seed: 0xC0FFEE)
        for _ in 0..<25 {
            let shuffled = generator.drawShuffled(events)
            #expect(DifficultyLadder.fold(shuffled).states == expected.states)
        }
    }

    @Test("Two devices interleaving offline work converge on the same level")
    func devicesConverge() {
        // Same wall-clock second on both devices — the deviceID tiebreak is what decides.
        let deviceA = (0..<5).map { ordinal in
            EventFactory.attempt(.c, key: key, device: "device-a", ordinal: ordinal, secondsOffset: 10)
        }
        let deviceB = (0..<5).map { ordinal in
            EventFactory.attempt(.w, key: key, device: "device-b", ordinal: ordinal, secondsOffset: 10)
        }

        let aFirst = DifficultyLadder.fold(deviceA + deviceB)
        let bFirst = DifficultyLadder.fold(deviceB + deviceA)
        #expect(aFirst.states == bFirst.states)
    }
}
