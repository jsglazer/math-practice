//  MacWorksheetExporter.swift
//  The only `WorksheetExporting` conformance in the app. macOS target only — this file is
//  excluded from the iOS target's sources in `project.yml`, so it does not compile there.

import Foundation
import MathPracticeCore
import WebKit

struct MacWorksheetExporter: WorksheetExporting {
    /// US Letter at 72dpi, with a comfortable margin for handwritten working.
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

    @MainActor
    func export(worksheet: Worksheet, to url: URL) async throws {
        let renderer = MathRenderer()
        let configuration = WKPDFConfiguration()
        configuration.rect = Self.pageRect

        // `pdfData(for:)` awaits the KaTeX completion signal and re-checks the rendered
        // state before it will call through to createPDF — see MathRenderer.
        let data = try await renderer.pdfData(for: .worksheet(worksheet), configuration: configuration)
        try data.write(to: url, options: .atomic)
    }
}
