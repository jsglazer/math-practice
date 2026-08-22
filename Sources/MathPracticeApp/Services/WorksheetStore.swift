//  WorksheetStore.swift
//  Persisting and reading back the frozen worksheets.
//
//  Exporting persists FIRST and renders the PDF from the persisted record, so the printed
//  question numbers and the self-report rows are the same ordinals by construction.

import Foundation
import MathPracticeCore
import SwiftData

@MainActor
final class WorksheetStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Freezes and saves a worksheet. Call this before rendering anything.
    @discardableResult
    func persist(name: String, problems: [GeneratedProblem], createdAt: Date = Date()) throws -> Worksheet {
        let worksheet = WorksheetBuilder.make(
            id: UUID(),
            name: name,
            createdAt: createdAt,
            problems: problems
        )
        let record = WorksheetRecord(worksheet: worksheet)
        context.insert(record)
        for question in worksheet.questions {
            let questionRecord = WorksheetQuestionRecord(question: question, createdAt: createdAt)
            questionRecord.worksheet = record
            context.insert(questionRecord)
        }
        try context.save()
        return worksheet
    }

    /// Every saved worksheet, newest first.
    func all() -> [Worksheet] {
        let descriptor = FetchDescriptor<WorksheetRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap(Self.worksheet(from:))
    }

    static func worksheet(from record: WorksheetRecord) -> Worksheet? {
        let questions = (record.questions ?? [])
            .sorted { $0.index < $1.index }
            .compactMap(\.worksheetQuestion)
        guard !questions.isEmpty else { return nil }
        return Worksheet(
            id: record.worksheetID,
            dedupeKey: record.dedupeKey,
            name: record.name,
            createdAt: record.createdAt,
            questions: questions
        )
    }
}
