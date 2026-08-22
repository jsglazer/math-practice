//  KeyExporterInstaller.swift (iOS)
//  The iOS half of the platform gate. There is no iOS conformance to `KeyExporting`,
//  so there is nothing to return — and `Export/macOS/` is not in this target's sources, so
//  `MacKeyExporter` is not merely unused here, it does not exist.

enum KeyExporterInstaller {
    /// iOS has no PDF export. The UI hides the affordance when this is `nil`.
    static func make() -> (any KeyExporting)? {
        nil
    }
}
