//  EventStore.swift
//  Appending to, and reading back, the one synced write surface.
//
//  Everything the app records — attempts, worksheet self-reports, manual level overrides,
//  ladder-threshold changes — goes through `append`. Nothing else writes to the Log store,
//  and nothing anywhere mutates or deletes an event once it is in.

import Foundation
import MathPracticeCore
import SwiftData

@MainActor
final class EventStore {
    private let context: ModelContext
    private let deviceID: DeviceID
    private let clock: () -> Date

    init(context: ModelContext, deviceID: DeviceID, clock: @escaping () -> Date = Date.init) {
        self.context = context
        self.deviceID = deviceID
        self.clock = clock
    }

    /// Every event in the store, as the pure values core folds over.
    func allEvents() -> [PracticeEvent] {
        let descriptor = FetchDescriptor<EventRecord>(sortBy: [SortDescriptor(\.createdAt)])
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap(\.practiceEvent)
    }

    /// The next monotonic ordinal for this device.
    ///
    /// Derived from the store rather than kept in UserDefaults: local counter state that can
    /// drift from the store is exactly how two events end up sharing an identity.
    func nextOrdinal() -> Int {
        let identifier = deviceID.rawValue
        var descriptor = FetchDescriptor<EventRecord>(
            predicate: #Predicate { $0.deviceIdentifier == identifier },
            sortBy: [SortDescriptor(\.ordinal, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let highest = (try? context.fetch(descriptor))?.first?.ordinal ?? -1
        return highest + 1
    }

    /// Appends one event. Returns the event that was written.
    @discardableResult
    func append(
        kind: PracticeEventKind,
        key: PracticeKey?,
        difficulty: Int?,
        templateID: TemplateID?,
        problemID: String? = nil
    ) -> PracticeEvent {
        let event = PracticeEvent(
            id: UUID(),
            createdAt: clock(),
            deviceID: deviceID,
            ordinal: nextOrdinal(),
            key: key,
            difficulty: difficulty,
            templateID: templateID,
            problemID: problemID,
            kind: kind
        )
        append(event)
        return event
    }

    /// Appends pre-built events — the worksheet self-report path builds a batch in core.
    func append(_ events: [PracticeEvent]) {
        for event in events {
            context.insert(EventRecord(event: event))
        }
        try? context.save()
    }

    func append(_ event: PracticeEvent) {
        append([event])
    }

    // MARK: - Convenience writers

    func recordAttempt(_ outcome: AttemptOutcome, problem: GeneratedProblem) {
        append(
            kind: .attempt(outcome),
            key: problem.practiceKey,
            difficulty: problem.difficulty,
            templateID: problem.templateID,
            problemID: problem.problemID
        )
    }

    /// Records a skip, with an optional note the user typed for later review.
    func recordSkip(problem: GeneratedProblem, note: String?) {
        append(
            kind: .skipped(note: note),
            key: problem.practiceKey,
            difficulty: problem.difficulty,
            templateID: problem.templateID,
            problemID: problem.problemID
        )
    }

    func recordLadderConfiguration(_ configuration: LadderConfiguration) {
        append(kind: .ladderConfiguration(configuration), key: nil, difficulty: nil, templateID: nil)
    }

    func recordManualLevel(_ level: Int, for key: PracticeKey) {
        append(kind: .manualLevelOverride(level: level), key: key, difficulty: nil, templateID: nil)
    }

    /// Appends a whole worksheet self-report session in one batch, numbering the ordinals
    /// consecutively so each event keeps a distinct identity.
    func recordWorksheetSelfReport(worksheet: Worksheet, outcomes: [Int: AttemptOutcome]) {
        let first = nextOrdinal()
        let identifiers = (0..<outcomes.count).map { _ in UUID() }
        let events = WorksheetBuilder.selfReportEvents(
            worksheet: worksheet,
            outcomes: outcomes,
            stamping: EventStamping(
                deviceID: deviceID,
                firstOrdinal: first,
                timestamp: clock(),
                identifiers: identifiers
            )
        )
        append(events)
    }
}
