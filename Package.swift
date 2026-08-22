// swift-tools-version: 6.0
// MathPractice — paper-first calculus drill app for macOS & iOS.
// Targeted toolchain: Swift 6.3.3 / Xcode 26.6 / macOS SDK 26.5 / iOS SDK 26.5.
//
// Packaging is the DevNotes hybrid: this package owns the pure domain library and the
// headless test gate; `project.yml` (XcodeGen) generates the signed, entitled macOS and
// iOS app targets that link `MathPracticeCore`. `swift test` never needs the app targets.
import PackageDescription

let package = Package(
    name: "MathPractice",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        // Platform-agnostic domain logic. The whole headless test suite runs against this.
        .library(name: "MathPracticeCore", targets: ["MathPracticeCore"]),
        // Build-time-only dump used by the offline SymPy verifier. Never shipped.
        .executable(name: "TemplateDump", targets: ["TemplateDump"])
    ],
    targets: [
        // MARK: - Pure core
        // No SwiftUI, no WebKit, no SwiftData, no AppKit/UIKit, no file or network I/O.
        .target(
            name: "MathPracticeCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // MARK: - Build-time template dump (feeds Tools/verify_templates/verify_templates.py)
        .executableTarget(
            name: "TemplateDump",
            dependencies: ["MathPracticeCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // MARK: - Deterministic headless tests (the machine-checkable gate)
        .testTarget(
            name: "MathPracticeCoreTests",
            dependencies: ["MathPracticeCore"],
            resources: [
                .copy("Golden")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
