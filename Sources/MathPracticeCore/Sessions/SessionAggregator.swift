//  SessionAggregator.swift
//  Groups the event stream into practice sessions, purely by looking at the gaps between
//  timestamps — like the dashboard and the ladder, nothing here is stored. A session is
//  never opened or closed explicitly; it is just a run of attempts and skips close enough
//  together in time to be "one sitting".

import Foundation

/// One problem worked or skipped, as it appears in a session review.
public struct SessionEntry: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let key: PracticeKey?
    public let difficulty: Int?
    public let templateID: TemplateID?
    public let problemID: String?
    public let outcome: AttemptOutcome?
    public let skipNote: String?

    public var isSkip: Bool { outcome == nil }
}

/// One contiguous run of practice.
public struct PracticeSession: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    /// Most recent first, matching how a person reviews what they just did.
    public let entries: [SessionEntry]

    public var attempts: Int { entries.filter { !$0.isSkip }.count }
    public var correct: Int { entries.filter { $0.outcome == .correct }.count }
    public var skips: Int { entries.filter(\.isSkip).count }
}

public enum SessionAggregator {
    /// A new session starts once the gap since the previous entry exceeds this — long
    /// enough that a pause to think doesn't fracture a session, short enough that
    /// yesterday's drilling doesn't merge into today's.
    public static let sessionGap: TimeInterval = 30 * 60

    /// Builds sessions from the event stream, most recent session first.
    public static func sessions(from events: [PracticeEvent]) -> [PracticeSession] {
        let relevant = events
            .filter { event in
                switch event.kind {
                case .attempt, .skipped: return true
                case .worksheetSelfReport, .manualLevelOverride, .ladderConfiguration: return false
                }
            }
            .sorted { $0.createdAt < $1.createdAt }
        guard !relevant.isEmpty else { return [] }

        var groups: [[PracticeEvent]] = []
        var current: [PracticeEvent] = []
        var previous: Date?
        for event in relevant {
            if let previous, event.createdAt.timeIntervalSince(previous) > sessionGap {
                groups.append(current)
                current = []
            }
            current.append(event)
            previous = event.createdAt
        }
        if !current.isEmpty { groups.append(current) }

        return groups
            .compactMap(session(from:))
            .sorted { $0.startedAt > $1.startedAt }
    }

    private static func session(from group: [PracticeEvent]) -> PracticeSession? {
        guard let first = group.first, let last = group.last else { return nil }
        let entries = group
            .map { event in
                SessionEntry(
                    id: event.id,
                    createdAt: event.createdAt,
                    key: event.key,
                    difficulty: event.difficulty,
                    templateID: event.templateID,
                    problemID: event.problemID,
                    outcome: event.kind.outcome,
                    skipNote: event.kind.skipNote
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
        return PracticeSession(id: first.id, startedAt: first.createdAt, endedAt: last.createdAt, entries: entries)
    }
}

private extension PracticeEventKind {
    var skipNote: String? {
        if case let .skipped(note) = self { return note }
        return nil
    }
}
