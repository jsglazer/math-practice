//  LadderConfiguration.swift
//  The tunable part of the adaptive ladder.
//
//  These values are NOT read from UserDefaults: they are recorded as configuration events
//  in the synced stream, so every device resolves the same effective value from the same
//  data. UserDefaults holds only device-local UI preferences that cannot affect any
//  derived value.

/// Thresholds governing how the difficulty ladder moves.
public struct LadderConfiguration: Hashable, Sendable, Codable {
    /// Consecutive correct answers needed to step up a level.
    public var stepUpThreshold: Int
    /// Consecutive incorrect answers needed to step down a level.
    public var stepDownThreshold: Int
    /// Attempts that must pass after a step down before another step down is allowed.
    public var holdPeriod: Int

    public init(stepUpThreshold: Int, stepDownThreshold: Int, holdPeriod: Int) {
        self.stepUpThreshold = max(1, stepUpThreshold)
        self.stepDownThreshold = max(1, stepDownThreshold)
        self.holdPeriod = max(0, holdPeriod)
    }

    public static let `default` = LadderConfiguration(
        stepUpThreshold: 3,
        stepDownThreshold: 2,
        holdPeriod: 2
    )

    /// The ranges Settings offers. Clamping here keeps a bad synced value from wedging the ladder.
    public static let stepUpBounds = 1...10
    public static let stepDownBounds = 1...10
    public static let holdBounds = 0...10

    public var clamped: LadderConfiguration {
        LadderConfiguration(
            stepUpThreshold: Self.clamp(stepUpThreshold, to: Self.stepUpBounds),
            stepDownThreshold: Self.clamp(stepDownThreshold, to: Self.stepDownBounds),
            holdPeriod: Self.clamp(holdPeriod, to: Self.holdBounds)
        )
    }

    private static func clamp(_ value: Int, to bounds: ClosedRange<Int>) -> Int {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }
}
