//  SessionExporterInstaller.swift (iOS)
//  The iOS half of the platform gate. There is no iOS conformance to `SessionExporting`,
//  so there is nothing to return — and `Export/macOS/` is not in this target's sources, so
//  `MacSessionExporter` is not merely unused here, it does not exist.

enum SessionExporterInstaller {
    /// iOS has no PDF export. The UI hides the affordance when this is `nil`.
    static func make() -> (any SessionExporting)? {
        nil
    }
}
