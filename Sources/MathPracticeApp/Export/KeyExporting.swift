//  KeyExporting.swift
//  PDF export of every flagged Key problem exists only on macOS, gated the same way as
//  `SessionExporting` and `WorksheetExporting` — see those files' notes. `Export/macOS/`
//  and `Export/iOS/` are each excluded from the other platform's target in `project.yml`.

import Foundation
import MathPracticeCore

/// Turns every flagged Key problem into one PDF on disk.
protocol KeyExporting: Sendable {
    @MainActor
    func export(keyProblems: [KeyProblemRecord], registry: TopicRegistry, to url: URL) async throws
}

extension KeyExporting {
    var suggestedFilename: String { "Key Problems.pdf" }
}
