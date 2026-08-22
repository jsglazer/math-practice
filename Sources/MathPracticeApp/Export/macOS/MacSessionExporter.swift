//  MacSessionExporter.swift
//  The only `SessionExporting` conformance in the app. macOS target only — this file is
//  excluded from the iOS target's sources in `project.yml`, so it does not compile there.

import Foundation
import MathPracticeCore
import WebKit

struct MacSessionExporter: SessionExporting {
    /// US Letter at 72dpi — matches `MacWorksheetExporter`.
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

    @MainActor
    func export(
        session: PracticeSession,
        registry: TopicRegistry,
        detail: SessionExportDetail,
        resolve: (SessionEntry) -> GeneratedProblem?,
        to url: URL
    ) async throws {
        let document = MathDocument.session(session, registry: registry, detail: detail, resolve: resolve)
        let renderer = MathRenderer()
        let configuration = WKPDFConfiguration()
        configuration.rect = Self.pageRect

        let data = try await renderer.pdfData(for: document, configuration: configuration)
        try data.write(to: url, options: .atomic)
    }
}
