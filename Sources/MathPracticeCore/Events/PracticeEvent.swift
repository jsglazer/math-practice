//  PracticeEvent.swift
//  The append-only event stream. This is the entire synced write surface of the app.
//
//  Nothing here is ever mutated or deleted after insert, except by the dedup service
//  collapsing sync-level duplicates. Attempts, worksheet self-reports, manual difficulty
//  overrides and ladder-threshold changes are ALL events in this one stream — which is
//  what lets the difficulty level be derived rather than stored, and therefore what makes
//  multi-device offline-first merging conflict-free.

import Foundation

/// Identifies the device that appended an event. Part of the total event ordering.
public struct DeviceID: StringIdentifier, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// A self-reported result. The app never grades, so there is no third state.
public enum AttemptOutcome: String, Hashable, Sendable, Codable, CaseIterable {
    case correct
    case incorrect

    public var isCorrect: Bool { self == .correct }
}

/// What an event records.
public enum PracticeEventKind: Hashable, Sendable, Codable {
    /// A problem worked in the app and self-reported.
    case attempt(AttemptOutcome)
    /// A problem worked on a printed worksheet and self-reported afterwards.
    case worksheetSelfReport(AttemptOutcome, worksheetID: UUID, questionNumber: Int)
    /// The user pinned a `(topic, sub-type)` to a level from Settings.
    case manualLevelOverride(level: Int)
    /// The user changed the ladder thresholds. Applies to every key from this point forward.
    case ladderConfiguration(LadderConfiguration)

    /// A short stable tag used in the dedupe key and in persistence.
    public var tag: String {
        switch self {
        case .attempt: return "attempt"
        case .worksheetSelfReport: return "worksheet-report"
        case .manualLevelOverride: return "level-override"
        case .ladderConfiguration: return "ladder-config"
        }
    }

    /// The self-reported outcome, for the kinds that carry one.
    public var outcome: AttemptOutcome? {
        switch self {
        case let .attempt(outcome): return outcome
        case let .worksheetSelfReport(outcome, _, _): return outcome
        case .manualLevelOverride, .ladderConfiguration: return nil
        }
    }
}

/// One immutable entry in the stream.
public struct PracticeEvent: Hashable, Sendable, Codable, Identifiable {
    public let id: UUID
    /// A deterministic digest of this event's logical identity. Dedup is defined on this,
    /// never on object identity and never on a SwiftData persistent ID.
    public let dedupeKey: String
    public let createdAt: Date
    public let deviceID: DeviceID
    /// Monotonic per-device counter. With `deviceID` it makes the event logically unique.
    public let ordinal: Int
    /// The `(topic, sub-type)` this event applies to. `nil` for app-wide configuration.
    public let key: PracticeKey?
    /// The difficulty the problem was posed at. `nil` for non-attempt events.
    public let difficulty: Int?
    public let templateID: TemplateID?
    public let kind: PracticeEventKind

    public init(
        id: UUID,
        createdAt: Date,
        deviceID: DeviceID,
        ordinal: Int,
        key: PracticeKey?,
        difficulty: Int?,
        templateID: TemplateID?,
        kind: PracticeEventKind
    ) {
        self.id = id
        self.createdAt = createdAt
        self.deviceID = deviceID
        self.ordinal = ordinal
        self.key = key
        self.difficulty = difficulty
        self.templateID = templateID
        self.kind = kind
        self.dedupeKey = DedupeKey.event(kind: kind.tag, deviceID: deviceID, ordinal: ordinal)
    }

    /// Rebuilds an event read back from storage, preserving the stored dedupe key.
    public init(
        id: UUID,
        dedupeKey: String,
        createdAt: Date,
        deviceID: DeviceID,
        ordinal: Int,
        key: PracticeKey?,
        difficulty: Int?,
        templateID: TemplateID?,
        kind: PracticeEventKind
    ) {
        self.id = id
        self.dedupeKey = dedupeKey
        self.createdAt = createdAt
        self.deviceID = deviceID
        self.ordinal = ordinal
        self.key = key
        self.difficulty = difficulty
        self.templateID = templateID
        self.kind = kind
    }
}

/// The total order every device agrees on: timestamp, then device, then event id.
///
/// Because this order is total and derived only from stored fields, every fold over the
/// stream is a pure function of the *set* of events — two devices that have seen the same
/// events compute the same answer regardless of the order they arrived in.
public enum EventOrdering {
    public static func precedes(_ lhs: PracticeEvent, _ rhs: PracticeEvent) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        if lhs.deviceID.rawValue != rhs.deviceID.rawValue {
            return lhs.deviceID.rawValue < rhs.deviceID.rawValue
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    public static func sorted(_ events: [PracticeEvent]) -> [PracticeEvent] {
        events.sorted(by: precedes)
    }
}
