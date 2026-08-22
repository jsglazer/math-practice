//  DedupeResolution.swift
//  The pure half of deduplication. The SwiftData deletion is a thin shell around this.
//
//  Resolution is deliberately NOT wall-clock last-writer-wins: that is not order-
//  independent, and two devices replaying the same records in different orders can
//  converge on different survivors. The survivor here is the record with the earliest
//  `createdAt`, ties broken by the lexicographically smallest UUID string — a total order
//  on the record set, so every device picks the same one, every time, from any order.

import Foundation

/// Anything the dedup pass can operate on. Conformed by the pure `PracticeEvent` and, in
/// the app shell, by the SwiftData record types.
public protocol Deduplicable {
    var dedupeKey: String { get }
    var createdAt: Date { get }
    var recordID: UUID { get }
}

extension PracticeEvent: Deduplicable {
    public var recordID: UUID { id }
}

/// What a dedup pass decided.
/// `Record` is deliberately unconstrained beyond `Deduplicable`: the same plan runs over
/// the pure `PracticeEvent` in tests and over the app's SwiftData records in the shell,
/// and SwiftData model classes are not `Sendable`.
public struct DedupePlan<Record> {
    /// One record per distinct `dedupeKey`, in first-appearance order of the key.
    public let survivors: [Record]
    /// Every record that must be deleted. Empty when the input is already clean.
    public let redundant: [Record]

    public var isClean: Bool { redundant.isEmpty }
}

public enum DedupeResolution {
    /// Groups `records` by `dedupeKey` and picks one survivor per group.
    ///
    /// Idempotent: feeding the survivors back in yields the same survivors and no
    /// redundant records. Order-independent: the result does not depend on input order.
    public static func plan<Record>(
        for records: [Record]
    ) -> DedupePlan<Record> where Record: Deduplicable {
        var keyOrder: [String] = []
        var groups: [String: [Record]] = [:]
        for record in records {
            if groups[record.dedupeKey] == nil {
                keyOrder.append(record.dedupeKey)
                groups[record.dedupeKey] = []
            }
            groups[record.dedupeKey]?.append(record)
        }

        var survivors: [Record] = []
        var redundant: [Record] = []
        for key in keyOrder {
            guard let group = groups[key], let winner = survivor(of: group) else { continue }
            survivors.append(winner)
            redundant.append(contentsOf: group.filter { $0.recordID != winner.recordID })
        }
        return DedupePlan(survivors: survivors, redundant: redundant)
    }

    /// The survivor of one group: earliest `createdAt`, smallest UUID string on a tie.
    public static func survivor<Record>(
        of group: [Record]
    ) -> Record? where Record: Deduplicable {
        group.min { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.recordID.uuidString < rhs.recordID.uuidString
        }
    }
}
