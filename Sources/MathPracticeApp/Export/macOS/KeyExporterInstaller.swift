//  KeyExporterInstaller.swift (macOS)
//  The macOS half of the platform gate. Its iOS counterpart lives in `Export/iOS/` and
//  returns `nil`; the build system picks one, so no view ever branches on the platform.

enum KeyExporterInstaller {
    /// macOS ships the exporter.
    static func make() -> (any KeyExporting)? {
        MacKeyExporter()
    }
}
