//  DifficultyLadder.swift
//  The adaptive difficulty ladder, computed rather than stored.
//
//  The per-(topic, sub-type) level is NEVER a synced mutable row. It is a pure fold over
//  the event stream, sorted into the single total order every device agrees on, so two
//  devices holding the same events always agree on the level without ever having to merge
//  a conflicting write. Cache it in memory if you like; never persist it.

/// The ladder state for one `(topic, sub-type)` pair.
public struct LadderState: Hashable, Sendable {
    public var level: Int
    public var consecutiveSuccesses: Int
    public var consecutiveFailures: Int
    /// Attempts still to elapse before another step down is permitted.
    public var holdRemaining: Int

    public init(
        level: Int = DifficultyLadder.bounds.lowerBound,
        consecutiveSuccesses: Int = 0,
        consecutiveFailures: Int = 0,
        holdRemaining: Int = 0
    ) {
        self.level = level
        self.consecutiveSuccesses = consecutiveSuccesses
        self.consecutiveFailures = consecutiveFailures
        self.holdRemaining = holdRemaining
    }
}

/// The complete derived view of the ladder across every key seen in the stream.
public struct LadderSnapshot: Hashable, Sendable {
    public let configuration: LadderConfiguration
    public let states: [PracticeKey: LadderState]

    /// The level for `key`, defaulting to the bottom of the ladder for an unseen key.
    public func level(for key: PracticeKey) -> Int {
        states[key]?.level ?? DifficultyLadder.bounds.lowerBound
    }

    public func state(for key: PracticeKey) -> LadderState {
        states[key] ?? LadderState()
    }
}

public enum DifficultyLadder {
    public static let bounds = 1...10

    public static func clamp(_ level: Int) -> Int {
        min(max(level, bounds.lowerBound), bounds.upperBound)
    }

    /// Folds the whole stream into the derived ladder.
    ///
    /// Pure and order-independent: the events are sorted into the canonical total order
    /// first, so the result depends only on the *set* of events handed in.
    public static func fold(
        _ events: [PracticeEvent],
        initialConfiguration: LadderConfiguration = .default
    ) -> LadderSnapshot {
        var configuration = initialConfiguration.clamped
        var states: [PracticeKey: LadderState] = [:]

        for event in EventOrdering.sorted(events) {
            switch event.kind {
            case let .ladderConfiguration(updated):
                // Applies from this point in the stream forward, exactly as it did on the
                // device that made the change.
                configuration = updated.clamped

            case let .manualLevelOverride(level):
                guard let key = event.key else { continue }
                // A manual pin restarts the ladder from that level with a clean slate.
                states[key] = LadderState(level: clamp(level))

            case .attempt, .worksheetSelfReport:
                guard let key = event.key, let outcome = event.kind.outcome else { continue }
                var state = states[key] ?? LadderState()
                apply(outcome: outcome, to: &state, configuration: configuration)
                states[key] = state

            case .skipped:
                // Neither right nor wrong — a skip carries no signal for the ladder.
                continue
            }
        }

        return LadderSnapshot(configuration: configuration, states: states)
    }

    /// The effective ladder configuration — the latest configuration event in the stream.
    public static func configuration(
        in events: [PracticeEvent],
        initial: LadderConfiguration = .default
    ) -> LadderConfiguration {
        fold(events, initialConfiguration: initial).configuration
    }

    /// The derived level for one key.
    public static func level(
        for key: PracticeKey,
        in events: [PracticeEvent],
        initialConfiguration: LadderConfiguration = .default
    ) -> Int {
        fold(events, initialConfiguration: initialConfiguration).level(for: key)
    }

    /// The single transition rule. One attempt in, one state change out.
    static func apply(
        outcome: AttemptOutcome,
        to state: inout LadderState,
        configuration: LadderConfiguration
    ) {
        // The hold is read before it burns down, so a hold of N blocks exactly N attempts.
        let onHold = state.holdRemaining > 0
        if state.holdRemaining > 0 {
            state.holdRemaining -= 1
        }

        switch outcome {
        case .correct:
            state.consecutiveSuccesses += 1
            state.consecutiveFailures = 0
            if state.consecutiveSuccesses >= configuration.stepUpThreshold {
                state.consecutiveSuccesses = 0
                if state.level < bounds.upperBound {
                    state.level += 1
                }
            }

        case .incorrect:
            state.consecutiveFailures += 1
            state.consecutiveSuccesses = 0
            if state.consecutiveFailures >= configuration.stepDownThreshold, !onHold {
                state.consecutiveFailures = 0
                if state.level > bounds.lowerBound {
                    state.level -= 1
                    // Only an actual step down arms the hold; bottoming out does not.
                    state.holdRemaining = configuration.holdPeriod
                }
            }
        }
    }
}
