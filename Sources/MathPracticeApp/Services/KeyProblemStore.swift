//  KeyProblemStore.swift
//  Persisting and reading back problems flagged "Key" for later review.
//
//  A problem is flagged at most once — `problemID` is the natural key, so re-flagging an
//  already-flagged problem is a no-op rather than a duplicate.

import Foundation
import MathPracticeCore
import SwiftData

@MainActor
final class KeyProblemStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Every flagged problem, newest first.
    func all() -> [KeyProblemRecord] {
        let descriptor = FetchDescriptor<KeyProblemRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func record(for problemID: String) -> KeyProblemRecord? {
        let descriptor = FetchDescriptor<KeyProblemRecord>(
            predicate: #Predicate { $0.problemID == problemID }
        )
        return (try? context.fetch(descriptor))?.first
    }

    func isFlagged(_ problemID: String) -> Bool {
        record(for: problemID) != nil
    }

    /// Flags `problem` as Key. Returns the existing record if it was already flagged.
    @discardableResult
    func flag(_ problem: GeneratedProblem, note: String = "") -> KeyProblemRecord {
        if let existing = record(for: problem.problemID) {
            return existing
        }
        let newRecord = KeyProblemRecord(problem: problem, note: note)
        context.insert(newRecord)
        try? context.save()
        return newRecord
    }

    func unflag(_ problemID: String) {
        guard let existing = record(for: problemID) else { return }
        context.delete(existing)
        try? context.save()
    }

    func setNote(_ note: String, for problemID: String) {
        guard let existing = record(for: problemID) else { return }
        existing.note = note
        existing.updatedAt = Date()
        try? context.save()
    }
}
