//  SessionExporting.swift
//  PDF session-review export exists only on macOS, gated the same way as
//  `WorksheetExporting` — see that file's note. `Export/macOS/` and `Export/iOS/` are each
//  excluded from the other platform's target in `project.yml`.

import Foundation
import MathPracticeCore

/// How much of each entry's worked solution to include in a session export.
enum SessionExportDetail: String, CaseIterable, Identifiable, Sendable {
    case questionsOnly
    case allAnswers
    case allShownWork
    case shownWorkForWrongOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .questionsOnly: return "Questions only"
        case .allAnswers: return "All answers"
        case .allShownWork: return "All shown work"
        case .shownWorkForWrongOnly: return "Shown work for wrong answers only"
        }
    }

    /// Whether the answer/steps should be printed for an entry with this outcome.
    func includesWork(for outcome: AttemptOutcome?) -> Bool {
        switch self {
        case .questionsOnly: return false
        case .allAnswers, .allShownWork: return true
        case .shownWorkForWrongOnly: return outcome == .incorrect
        }
    }

    /// Whether the worked steps (not just the final answer) should be printed.
    var includesSteps: Bool {
        switch self {
        case .questionsOnly, .allAnswers: return false
        case .allShownWork, .shownWorkForWrongOnly: return true
        }
    }
}

/// Turns a past practice session into a PDF on disk.
protocol SessionExporting: Sendable {
    /// Renders `session` and writes it to `url`. `resolve` regenerates the exact problem
    /// instance an entry was posed with, or returns `nil` when the entry predates seed
    /// capture — the document still renders, printing a placeholder for that entry.
    @MainActor
    func export(
        session: PracticeSession,
        registry: TopicRegistry,
        detail: SessionExportDetail,
        resolve: (SessionEntry) -> GeneratedProblem?,
        to url: URL
    ) async throws

    /// A filename suggestion, e.g. "Session 2026-08-22.pdf".
    func suggestedFilename(for session: PracticeSession) -> String
}

extension SessionExporting {
    func suggestedFilename(for session: PracticeSession) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return "Session \(formatter.string(from: session.startedAt)).pdf"
    }
}
