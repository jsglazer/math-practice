//  DedupeTests.swift
//  Deterministic test requirement: insert mock duplicate attempts with different UUIDs
//  and verify they merge into a single record.
//
//  SwiftData with CloudKit cannot express a unique constraint, so this pure resolution is
//  the entire uniqueness guarantee. It has to hold under every arrival order.

import Foundation
import Testing
@testable import MathPracticeCore

/// A stand-in for a SwiftData record, so the pure resolution can be tested with no store.
private struct MockRecord: Deduplicable, Hashable, Sendable {
    let dedupeKey: String
    let createdAt: Date
    let recordID: UUID
}

@Suite("Deduplication")
struct DedupeTests {
    let key = PracticeKey(topic: .derivatives, subType: .productRule)

    // MARK: - The required case

    @Test("Duplicate attempts with different UUIDs merge into a single record")
    func duplicatesMergeToOne() {
        // The same logical attempt, arriving three times from CloudKit with three
        // different SwiftData object identities — exactly the sync-level duplicate the
        // audit warns would warp the ladder and the dashboards.
        let original = EventFactory.attempt(.correct, key: key, ordinal: 0)
        let duplicates = (1...2).map { EventFactory.syncCopy(of: original, copy: $0) }
        #expect(Set(([original] + duplicates).map(\.id)).count == 3)

        let plan = DedupeResolution.plan(for: [original] + duplicates)
        #expect(plan.survivors.count == 1)
        #expect(plan.redundant.count == 2)
        #expect(plan.survivors[0].dedupeKey == original.dedupeKey)
    }

    @Test("Merging duplicates leaves the derived level untouched")
    func duplicatesDoNotWarpTheLadder() {
        let events = EventFactory.run([.c, .c, .c], key: key)
        let tripled = events + events.map { EventFactory.syncCopy(of: $0, copy: 1) }
            + events.map { EventFactory.syncCopy(of: $0, copy: 2) }

        // Left alone, three copies of three successes read as nine and push the level to 4
        // — the exact warping the audit flagged.
        #expect(DifficultyLadder.level(for: key, in: tripled) == 4)

        let plan = DedupeResolution.plan(for: tripled)
        #expect(plan.survivors.count == 3)
        #expect(plan.redundant.count == 6)
        #expect(DifficultyLadder.level(for: key, in: plan.survivors) == 2)
    }

    // MARK: - Resolution rule

    @Test("The earliest createdAt survives, not the latest write")
    func earliestCreatedAtSurvives() {
        let base = EventFactory.base
        // The latest write carries the smallest UUID, so a last-writer-wins rule would
        // pick it and a smallest-UUID rule would too. Only the createdAt rule picks right.
        let records = [
            MockRecord(
                dedupeKey: "k",
                createdAt: base.addingTimeInterval(30),
                recordID: EventFactory.orderedUUID(0x00)
            ),
            MockRecord(dedupeKey: "k", createdAt: base, recordID: EventFactory.orderedUUID(0xFF)),
            MockRecord(
                dedupeKey: "k",
                createdAt: base.addingTimeInterval(10),
                recordID: EventFactory.orderedUUID(0x11)
            )
        ]
        let plan = DedupeResolution.plan(for: records)
        #expect(plan.survivors.count == 1)
        #expect(plan.survivors[0].createdAt == base)
    }

    @Test("Ties on createdAt break on the smallest UUID string")
    func tiesBreakOnSmallestUUID() {
        let base = EventFactory.base
        let small = EventFactory.orderedUUID(0x00)
        let large = EventFactory.orderedUUID(0xFF)
        let records = [
            MockRecord(dedupeKey: "k", createdAt: base, recordID: large),
            MockRecord(dedupeKey: "k", createdAt: base, recordID: small)
        ]
        #expect(DedupeResolution.plan(for: records).survivors[0].recordID == small)
        #expect(DedupeResolution.plan(for: records.reversed()).survivors[0].recordID == small)
    }

    @Test("Resolution is order-independent across every arrival order")
    func resolutionIsOrderIndependent() {
        let base = EventFactory.base
        let records = (0..<6).map { index in
            MockRecord(
                dedupeKey: index < 3 ? "alpha" : "beta",
                createdAt: base.addingTimeInterval(TimeInterval((index * 7) % 5)),
                recordID: EventFactory.uuid(device: "d", ordinal: index)
            )
        }
        let expected = Set(DedupeResolution.plan(for: records).survivors.map(\.recordID))

        var generator = RandomSource(seed: 99)
        for _ in 0..<40 {
            let shuffled = generator.drawShuffled(records)
            #expect(Set(DedupeResolution.plan(for: shuffled).survivors.map(\.recordID)) == expected)
        }
    }

    @Test("The pass is idempotent — running it on its own survivors changes nothing")
    func passIsIdempotent() {
        let events = EventFactory.run([.c, .w, .c], key: key)
        let withCopies = events + events.map { EventFactory.syncCopy(of: $0, copy: 1) }
        let first = DedupeResolution.plan(for: withCopies)
        #expect(first.redundant.count == 3)

        let second = DedupeResolution.plan(for: first.survivors)
        #expect(second.isClean)
        #expect(second.survivors.map(\.id) == first.survivors.map(\.id))
    }

    @Test("The same record listed twice is one record, not a duplicate to delete")
    func identicalRecordsAreNotDuplicates() {
        // Same dedupeKey *and* same UUID means one row seen twice — there is nothing to
        // delete, and reporting it as redundant would delete the survivor itself.
        let event = EventFactory.attempt(.correct, key: key, ordinal: 0)
        let plan = DedupeResolution.plan(for: [event, event])
        #expect(plan.survivors.count == 1)
        #expect(plan.isClean)
    }

    @Test("Distinct events are never merged")
    func distinctEventsSurvive() {
        let events = EventFactory.run([.c, .w, .c, .c], key: key)
        let plan = DedupeResolution.plan(for: events)
        #expect(plan.isClean)
        #expect(plan.survivors.count == 4)
    }

    @Test("Events from different devices with the same ordinal are distinct")
    func deviceIsPartOfIdentity() {
        let a = EventFactory.attempt(.correct, key: key, device: "device-a", ordinal: 4)
        let b = EventFactory.attempt(.correct, key: key, device: "device-b", ordinal: 4)
        #expect(a.dedupeKey != b.dedupeKey)
        #expect(DedupeResolution.plan(for: [a, b]).isClean)
    }

    // MARK: - Key construction

    @Test("Worksheet questions are keyed on worksheet id plus question index")
    func worksheetQuestionKeys() {
        let worksheetID = EventFactory.orderedUUID(0x3F)
        let first = DedupeKey.worksheetQuestion(worksheetID: worksheetID, questionIndex: 0)
        let second = DedupeKey.worksheetQuestion(worksheetID: worksheetID, questionIndex: 1)
        #expect(first != second)
        #expect(first == DedupeKey.worksheetQuestion(worksheetID: worksheetID, questionIndex: 0))
    }

    @Test("Pack problems are keyed on identifier, version and index")
    func packProblemKeys() {
        let v1 = DedupeKey.packProblem(identifier: "llm-chain", version: 1, problemIndex: 3)
        let v2 = DedupeKey.packProblem(identifier: "llm-chain", version: 2, problemIndex: 3)
        #expect(v1 != v2)
    }

    @Test("An event's dedupe key is a pure function of kind, device and ordinal")
    func eventKeyIsDeterministic() {
        let event = EventFactory.attempt(.correct, key: key, device: "abc", ordinal: 12)
        #expect(event.dedupeKey == DedupeKey.event(kind: "attempt", deviceID: DeviceID("abc"), ordinal: 12))
    }
}
