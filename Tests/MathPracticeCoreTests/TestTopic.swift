//  TestTopic.swift
//  A topic the app has never heard of, used to prove the extensibility claim.
//
//  If adding a topic really is "one directory plus one array line", then a topic defined
//  entirely inside the test target must be able to drive the selector, the router, the
//  ladder and the dashboard without a single change to any core model. That is what the
//  suites in TopicRegistryTests do with this type.

import Foundation
@testable import MathPracticeCore

extension TopicID {
    static let testTopic = TopicID("test-topic")
}

extension SubTypeID {
    static let testDoubling = SubTypeID("doubling")
    static let testSquaring = SubTypeID("squaring")
}

/// `a x + b`, differentiated. Deliberately trivial — the point is registration, not maths.
struct DoublingTemplate: ProblemTemplate {
    let id = TemplateID("test-topic.doubling.linear")
    let subTypeID = SubTypeID.testDoubling
    let displayName = "Doubling"
    let difficultyRange = 1...10
    let instruction = "Double the coefficient"

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let a = generator.drawNonZeroInt(in: 1...(difficulty + 1))
        let b = generator.drawInt(in: 0...difficulty)
        let problem = Expression.sum([powerTerm(a, 1), .integer(b)]).simplified()
        let answer = Expression.integer(a)
        return ProblemDraw(
            parameters: [
                ProblemParameter(name: "a", value: a),
                ProblemParameter(name: "b", value: b)
            ],
            problem: problem,
            answer: answer,
            steps: [
                .narrative("The constant vanishes", latex: "0"),
                SolutionStep(title: "Read off the coefficient", expression: answer)
            ]
        )
    }
}

/// A second sub-type, so "random mix within a topic" has something to mix.
struct SquaringTemplate: ProblemTemplate {
    let id = TemplateID("test-topic.squaring.quadratic")
    let subTypeID = SubTypeID.testSquaring
    let displayName = "Squaring"
    let difficultyRange = 4...10
    let instruction = "Differentiate the square"

    func draw(difficulty: Int, using generator: inout RandomSource) -> ProblemDraw {
        let a = generator.drawNonZeroInt(in: 1...(difficulty + 1))
        let problem = powerTerm(a, 2)
        let answer = powerRuleDerivative(a, 2)
        return ProblemDraw(
            parameters: [ProblemParameter(name: "a", value: a)],
            problem: problem,
            answer: answer,
            steps: [
                .narrative("Apply the power rule", latex: "2 a x"),
                SolutionStep(title: "Multiply out", expression: answer)
            ]
        )
    }
}

/// The fake topic itself. Nothing in `MathPracticeCore` knows this type exists.
struct TestTopic: TopicModule {
    let id = TopicID.testTopic
    let displayName = "Test Topic"

    let subTypes: [SubType] = [
        SubType(id: .testDoubling, displayName: "Doubling"),
        SubType(id: .testSquaring, displayName: "Squaring")
    ]

    let templates: [any ProblemTemplate] = [
        DoublingTemplate(),
        SquaringTemplate()
    ]
}

// MARK: - Shared event-building helpers

enum EventFactory {
    /// A fixed base date, so nothing in the suite depends on the wall clock.
    static let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// Builds an event with a deterministic UUID derived from `ordinal` and `device`.
    static func attempt(
        _ outcome: AttemptOutcome,
        key: PracticeKey,
        difficulty: Int = 1,
        device: String = "device-a",
        ordinal: Int,
        secondsOffset: TimeInterval? = nil
    ) -> PracticeEvent {
        PracticeEvent(
            id: uuid(device: device, ordinal: ordinal),
            createdAt: base.addingTimeInterval(secondsOffset ?? TimeInterval(ordinal)),
            deviceID: DeviceID(device),
            ordinal: ordinal,
            key: key,
            difficulty: difficulty,
            templateID: nil,
            kind: .attempt(outcome)
        )
    }

    static func configuration(
        _ configuration: LadderConfiguration,
        device: String = "device-a",
        ordinal: Int,
        secondsOffset: TimeInterval? = nil
    ) -> PracticeEvent {
        PracticeEvent(
            id: uuid(device: device, ordinal: ordinal),
            createdAt: base.addingTimeInterval(secondsOffset ?? TimeInterval(ordinal)),
            deviceID: DeviceID(device),
            ordinal: ordinal,
            key: nil,
            difficulty: nil,
            templateID: nil,
            kind: .ladderConfiguration(configuration)
        )
    }

    static func override(
        level: Int,
        key: PracticeKey,
        device: String = "device-a",
        ordinal: Int,
        secondsOffset: TimeInterval? = nil
    ) -> PracticeEvent {
        PracticeEvent(
            id: uuid(device: device, ordinal: ordinal),
            createdAt: base.addingTimeInterval(secondsOffset ?? TimeInterval(ordinal)),
            deviceID: DeviceID(device),
            ordinal: ordinal,
            key: key,
            difficulty: nil,
            templateID: nil,
            kind: .manualLevelOverride(level: level)
        )
    }

    /// The same logical event arriving again from CloudKit under a fresh object identity:
    /// identical `dedupeKey`, different UUID. This is the duplicate the dedup pass exists
    /// for — two copies with the *same* UUID are literally one record and nothing to merge.
    static func syncCopy(of event: PracticeEvent, copy: Int) -> PracticeEvent {
        PracticeEvent(
            id: uuid(device: "sync-copy-\(copy)", ordinal: event.ordinal),
            dedupeKey: event.dedupeKey,
            createdAt: event.createdAt,
            deviceID: event.deviceID,
            ordinal: event.ordinal,
            key: event.key,
            difficulty: event.difficulty,
            templateID: event.templateID,
            kind: event.kind
        )
    }

    /// A UUID whose string form sorts by `leadingByte`, for testing the tiebreak rule.
    /// Built from bytes rather than parsed from a literal, so there is nothing to unwrap.
    static func orderedUUID(_ leadingByte: UInt8) -> UUID {
        UUID(uuid: (leadingByte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }

    /// A stable UUID for a `(device, ordinal)` pair — no randomness anywhere in the suite.
    static func uuid(device: String, ordinal: Int) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (offset, byte) in device.utf8.enumerated() where offset < 12 {
            bytes[offset] = byte
        }
        let ordinalBytes = withUnsafeBytes(of: UInt32(truncatingIfNeeded: ordinal).bigEndian) { Array($0) }
        for offset in 0..<4 {
            bytes[12 + offset] = ordinalBytes[offset]
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// A run of outcomes for one key, numbered from `firstOrdinal`.
    static func run(
        _ outcomes: [AttemptOutcome],
        key: PracticeKey,
        difficulty: Int = 1,
        device: String = "device-a",
        firstOrdinal: Int = 0
    ) -> [PracticeEvent] {
        outcomes.enumerated().map { offset, outcome in
            attempt(
                outcome,
                key: key,
                difficulty: difficulty,
                device: device,
                ordinal: firstOrdinal + offset
            )
        }
    }
}

extension AttemptOutcome {
    /// Compact notation for building runs: `.c` correct, `.w` wrong.
    static let c = AttemptOutcome.correct
    static let w = AttemptOutcome.incorrect
}
