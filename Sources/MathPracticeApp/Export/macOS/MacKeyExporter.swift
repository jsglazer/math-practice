//  MacKeyExporter.swift
//  The only `KeyExporting` conformance in the app. macOS target only — this file is
//  excluded from the iOS target's sources in `project.yml`, so it does not compile there.

import Foundation
import MathPracticeCore
import WebKit

struct MacKeyExporter: KeyExporting {
    /// US Letter at 72dpi — matches `MacSessionExporter` and `MacWorksheetExporter`.
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)

    @MainActor
    func export(keyProblems: [KeyProblemRecord], registry: TopicRegistry, to url: URL) async throws {
        let document = MathDocument.keyProblems(keyProblems, registry: registry)
        let renderer = MathRenderer()
        let configuration = WKPDFConfiguration()
        configuration.rect = Self.pageRect

        let data = try await renderer.pdfData(for: document, configuration: configuration)
        try data.write(to: url, options: .atomic)
    }
}
