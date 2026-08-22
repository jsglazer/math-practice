//  DeduplicationService.swift
//  The thin SwiftData shell around `DedupeResolution`.
//
//  SwiftData with CloudKit cannot express a unique constraint, so sync can and will deliver
//  the same logical record more than once under different object identities. This service
//  listens for remote changes, asks core which records to keep, and deletes the rest.
//
//  All of the decision-making lives in `MathPracticeCore.DedupeResolution` and is unit
//  tested there. Everything here is fetch, delete, save — and it is idempotent, so running
//  it on an already-clean store is a no-op.

import Combine
import CoreData
import Foundation
import MathPracticeCore
import SwiftData

@MainActor
final class DeduplicationService {
    private let context: ModelContext
    private var subscription: AnyCancellable?

    /// What the last pass removed, per record type. Surfaced in Settings for confidence.
    private(set) var lastPassRemoved: [String: Int] = [:]

    init(context: ModelContext) {
        self.context = context
    }

    /// Starts listening. Every CloudKit import ends in a remote-change notification, which
    /// is exactly when a duplicate can first become visible.
    func start() {
        subscription = NotificationCenter.default
            .publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.runPass()
            }
        runPass()
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
    }

    /// One idempotent pass over every syncable record type.
    @discardableResult
    func runPass() -> Int {
        var removed: [String: Int] = [:]
        removed["events"] = collapse(FetchDescriptor<EventRecord>())
        removed["worksheets"] = collapse(FetchDescriptor<WorksheetRecord>())
        removed["worksheetQuestions"] = collapse(FetchDescriptor<WorksheetQuestionRecord>())
        removed["packs"] = collapse(FetchDescriptor<PackRecord>())
        removed["packProblems"] = collapse(FetchDescriptor<PackProblemRecord>())

        let total = removed.values.reduce(0, +)
        if total > 0 {
            try? context.save()
        }
        lastPassRemoved = removed
        return total
    }

    /// Fetches one record type, asks core for the plan, and deletes what core rejected.
    private func collapse<Record>(_ descriptor: FetchDescriptor<Record>) -> Int
    where Record: PersistentModel & Deduplicable {
        guard let records = try? context.fetch(descriptor), !records.isEmpty else { return 0 }
        let plan = DedupeResolution.plan(for: records)
        for redundant in plan.redundant {
            context.delete(redundant)
        }
        return plan.redundant.count
    }
}

// MARK: - Deduplicable conformances
//
// Dedup is defined on `dedupeKey`, never on object identity and never on the SwiftData
// persistent ID. `recordID` here is the record's own stored UUID, which is stable across
// devices; the persistent ID is not.

extension EventRecord: Deduplicable {
    var recordID: UUID { eventID }
}

extension WorksheetRecord: Deduplicable {
    var recordID: UUID { worksheetID }
}

extension WorksheetQuestionRecord: Deduplicable {
    var recordID: UUID { questionID }
}

extension PackRecord: Deduplicable {
    /// Packs have no natural UUID; the dedupe key is `(identifier, version)`, and a stable
    /// UUID is derived from it so the tiebreak is deterministic across devices.
    var recordID: UUID { UUID.derived(from: dedupeKey) }
}

extension PackProblemRecord: Deduplicable {
    var recordID: UUID { UUID.derived(from: dedupeKey) }
}

extension UUID {
    /// A deterministic UUID from a string, so records without their own identifier still
    /// get an order-independent tiebreak. FNV-1a, seeded twice for 128 bits.
    static func derived(from text: String) -> UUID {
        var high: UInt64 = 0xCBF2_9CE4_8422_2325
        var low: UInt64 = 0x9E37_79B9_7F4A_7C15
        for byte in text.utf8 {
            high = (high ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            low = (low ^ UInt64(byte &+ 1)) &* 0x0000_0100_0000_01B3
        }
        let bytes = withUnsafeBytes(of: high.bigEndian, Array.init)
            + withUnsafeBytes(of: low.bigEndian, Array.init)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
