//  KeyProblemStore.swift
//  Persisting and reading back problems flagged "Key" for later review, and the notes taken
//  about a problem — starred or not.
//
//  A problem is flagged at most once — `problemID` is the natural key, so re-flagging an
//  already-flagged problem is a no-op rather than a duplicate. A note can exist on a problem
//  that was never starred: `isKey` on the record is what separates "starred" from "has a
//  note", not whether the record exists at all.

import Foundation
import MathPracticeCore
import SwiftData

@MainActor
final class KeyProblemStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Every starred problem, newest first — feeds the Key tab.
    func all() -> [KeyProblemRecord] {
        let descriptor = FetchDescriptor<KeyProblemRecord>(
            predicate: #Predicate { $0.isKey },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Every record with a note, starred or not — feeds note lookups everywhere a problem
    /// (Practice or Sessions) can be shown, independent of whether it's starred.
    func allRecords() -> [KeyProblemRecord] {
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
        record(for: problemID)?.isKey ?? false
    }

    /// Flags `problem` as Key. Reuses an existing note-only record if there is one, rather
    /// than making a second record for the same problem.
    @discardableResult
    func flag(_ problem: GeneratedProblem, note: String = "") -> KeyProblemRecord {
        if let existing = record(for: problem.problemID) {
            existing.isKey = true
            try? context.save()
            return existing
        }
        let newRecord = KeyProblemRecord(problem: problem, note: note, isKey: true)
        context.insert(newRecord)
        try? context.save()
        return newRecord
    }

    /// Un-stars `problemID`. Its note, if any, is kept (as a note-only record) so it isn't
    /// lost by an accidental un-star — only a record with no note is deleted outright.
    func unflag(_ problemID: String) {
        guard let existing = record(for: problemID) else { return }
        if existing.note.isEmpty {
            context.delete(existing)
        } else {
            existing.isKey = false
        }
        try? context.save()
    }

    /// Saves `note` against `problem`, creating a note-only (unstarred) record if none
    /// exists yet. Clearing the note on a record that was never starred removes it.
    func setNote(_ note: String, for problem: GeneratedProblem) {
        if let existing = record(for: problem.problemID) {
            if note.isEmpty && !existing.isKey {
                context.delete(existing)
            } else {
                existing.note = note
                existing.updatedAt = Date()
            }
        } else if !note.isEmpty {
            context.insert(KeyProblemRecord(problem: problem, note: note, isKey: false))
        }
        try? context.save()
    }
}
