//  WorksheetExporting.swift
//  PDF worksheet export exists only on macOS.
//
//  NOTE FOR REVIEW: the gate is this protocol having no iOS conformance, not `#if os(macOS)`
//  scattered through view bodies. `Export/macOS/` is excluded from the iOS target and
//  `Export/iOS/` from the macOS target in `project.yml`, so each platform compiles exactly
//  one `WorksheetExporterInstaller`. iOS ships `nil`, the UI asks the installer whether an
//  exporter exists, and the export button simply is not there — no preprocessor branch in
//  any view.

import Foundation
import MathPracticeCore

/// Turns a persisted worksheet into a PDF on disk.
protocol WorksheetExporting: Sendable {
    /// Renders `worksheet` and writes it to `url`.
    ///
    /// The worksheet must already be persisted before this is called: the PDF is rendered
    /// from the frozen record so the printed numbers and the in-app self-report rows are
    /// the same ordinals by construction.
    @MainActor
    func export(worksheet: Worksheet, to url: URL) async throws

    /// A filename suggestion, e.g. "Derivs 0821.pdf".
    func suggestedFilename(for worksheet: Worksheet) -> String
}

extension WorksheetExporting {
    func suggestedFilename(for worksheet: Worksheet) -> String {
        let safe = worksheet.name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
        return safe.isEmpty ? "Worksheet.pdf" : "\(safe).pdf"
    }
}
