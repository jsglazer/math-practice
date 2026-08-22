//  ArchitectureTests.swift
//  Machine-checks the structural guarantees the audit asked a human reviewer to read for.
//
//  These properties are invisible to an ordinary unit test — a rule like "the templates
//  module imports neither SwiftUI nor WebKit" is about what is NOT in the source, and only
//  a source scan can catch its reappearance. Cheap to run, and they fail loudly the moment
//  someone reaches for the convenient import.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Architecture guarantees")
struct ArchitectureTests {
    /// The repository root, derived from this file's own path so the suite is portable.
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MathPracticeCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // repository root

    /// Swift sources under `relativePath`, with comments removed.
    ///
    /// Scanning raw text would make every one of these checks fail on its own explanatory
    /// comment — the files that promise "no `@Attribute(.unique)`" say those words. What
    /// matters is the code, so the prose is stripped first.
    static func swiftFiles(under relativePath: String) throws -> [(url: URL, source: String)] {
        let root = repositoryRoot.appendingPathComponent(relativePath)
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var files: [(URL, String)] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let raw = try String(contentsOf: url, encoding: .utf8)
            files.append((url, strippingComments(from: raw)))
        }
        return files
    }

    /// Removes whole-line comments, block comments, and trailing comments on lines that
    /// hold no string literal — leaving anything ambiguous in place rather than mangling a
    /// literal that legitimately contains `//`, such as a URL.
    static func strippingComments(from source: String) -> String {
        var text = source
        while let start = text.range(of: "/*"),
              let end = text.range(of: "*/", range: start.upperBound..<text.endIndex) {
            text.replaceSubrange(start.lowerBound..<end.upperBound, with: "")
        }
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { return "" }
                guard !line.contains("\""), let marker = line.range(of: "//") else { return String(line) }
                return String(line[line.startIndex..<marker.lowerBound])
            }
            .joined(separator: "\n")
    }

    static func name(of url: URL) -> String {
        url.path.replacingOccurrences(of: repositoryRoot.path + "/", with: "")
    }

    // MARK: - Reviewer criterion: the core is platform-agnostic

    @Test("MathPracticeCore imports no UI, no WebKit and no SwiftData")
    func coreIsPure() throws {
        let banned = [
            "import SwiftUI", "import WebKit", "import SwiftData",
            "import AppKit", "import UIKit", "import CoreData", "import Combine"
        ]
        let files = try Self.swiftFiles(under: "Sources/MathPracticeCore")
        #expect(!files.isEmpty, "no core sources found — the path in this suite is wrong")

        for (url, source) in files {
            for statement in banned {
                #expect(
                    !source.contains(statement),
                    "\(Self.name(of: url)) contains '\(statement)' — core must stay platform-agnostic"
                )
            }
        }
    }

    @Test("The templates and topics modules import nothing but Foundation")
    func templatesAreFree() throws {
        for (url, source) in try Self.swiftFiles(under: "Sources/MathPracticeCore/Templates")
            + (try Self.swiftFiles(under: "Sources/MathPracticeCore/Topics"))
            + (try Self.swiftFiles(under: "Sources/MathPracticeCore/Expressions")) {
            let imports = source
                .split(separator: "\n")
                .filter { $0.hasPrefix("import ") }
                .map { $0.replacingOccurrences(of: "import ", with: "").trimmingCharacters(in: .whitespaces) }
            #expect(
                Set(imports).isSubset(of: ["Foundation"]),
                "\(Self.name(of: url)) imports \(imports) — expected Foundation at most"
            )
        }
    }

    @Test("Core does no file or network I/O")
    func coreDoesNoIO() throws {
        let banned = ["FileManager", "URLSession", "Bundle.", "UserDefaults", "Process("]
        for (url, source) in try Self.swiftFiles(under: "Sources/MathPracticeCore") {
            for symbol in banned {
                let reason = "OS services belong in the shell"
                #expect(
                    !source.contains(symbol),
                    "\(Self.name(of: url)) references '\(symbol)' — \(reason)"
                )
            }
        }
    }

    // MARK: - Seeded determinism

    @Test("Core never calls the unseeded random APIs")
    func coreHasNoFreeRandomness() throws {
        let banned = [".random(in:", ".randomElement()", ".shuffled()", "SystemRandomNumberGenerator"]
        for (url, source) in try Self.swiftFiles(under: "Sources/MathPracticeCore") {
            for symbol in banned {
                #expect(
                    !source.contains(symbol),
                    "\(Self.name(of: url)) uses '\(symbol)' — every draw must come from the injected RandomSource"
                )
            }
        }
    }

    // MARK: - Reviewer criterion: no SwiftData unique constraints

    @Test("No SwiftData model uses @Attribute(.unique) or #Unique")
    func noUniqueConstraints() throws {
        let banned = ["@Attribute(.unique", "#Unique"]
        let files = try Self.swiftFiles(under: "Sources/MathPracticeApp")
        #expect(!files.isEmpty, "no app sources found — the path in this suite is wrong")

        for (url, source) in files {
            for symbol in banned {
                let reason = "CloudKit cannot honour it; dedupe on dedupeKey instead"
                #expect(
                    !source.contains(symbol),
                    "\(Self.name(of: url)) uses '\(symbol)' — \(reason)"
                )
            }
        }
    }

    // MARK: - Reviewer criterion: the store split

    @Test("The Library and Log configurations declare disjoint model sets")
    func storesAreDisjoint() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot
                .appendingPathComponent("Sources/MathPracticeApp/Persistence/PersistenceController.swift"),
            encoding: .utf8
        )
        // Two configurations, two containers, one ModelContainer.
        #expect(source.contains("libraryCloudContainer"))
        #expect(source.contains("logCloudContainer"))
        #expect(source.contains("configurations: library, log"))

        // The library models must not appear in the log list, or vice versa.
        func models(in listName: String) -> Set<String> {
            guard let range = source.range(of: "static let \(listName): [any PersistentModel.Type] = ["),
                  let end = source.range(of: "]", range: range.upperBound..<source.endIndex) else {
                return []
            }
            return Set(
                source[range.upperBound..<end.lowerBound]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }
        let library = models(in: "libraryModels")
        let log = models(in: "logModels")
        #expect(!library.isEmpty)
        #expect(!log.isEmpty)
        #expect(library.isDisjoint(with: log), "a model type appears in both stores")
    }

    @Test("Both entitlements files declare both iCloud containers")
    func entitlementsDeclareBothContainers() throws {
        for name in ["MathPractice.entitlements", "MathPractice-iOS.entitlements"] {
            let text = try String(
                contentsOf: Self.repositoryRoot.appendingPathComponent(name),
                encoding: .utf8
            )
            for container in ["Library", "Log"] {
                #expect(
                    text.contains("iCloud.com.jsglazer.MathPractice.\(container)"),
                    "\(name) is missing the \(container) container"
                )
            }
        }
    }

    // MARK: - Reviewer criterion: render completion gates PDF export

    @Test("There is exactly one render-completion await point")
    func singleRenderAwaitPoint() throws {
        var continuations = 0
        for (_, source) in try Self.swiftFiles(under: "Sources/MathPracticeApp") {
            continuations += source.components(separatedBy: "withCheckedThrowingContinuation").count - 1
            // A polling loop or a timeout would be a race dressed up as a fix.
            let timer = "rendering must not be gated on a timer"
            #expect(!source.contains("Task.sleep"), "\(timer)")
            #expect(!source.contains("DispatchQueue.main.asyncAfter"), "\(timer)")
        }
        #expect(continuations == 1, "expected exactly one continuation, found \(continuations)")
    }

    @Test("PDF generation is reachable only through the completed render")
    func pdfGenerationIsGated() throws {
        let renderer = Self.strippingComments(from: try String(
            contentsOf: Self.repositoryRoot
                .appendingPathComponent("Sources/MathPracticeApp/Rendering/MathRenderer.swift"),
            encoding: .utf8
        ))
        // The await comes first, then the state is re-checked, then createPDF is called.
        let renderIndex = try #require(renderer.range(of: "try await render(document)"))
        let guardText = "guard state == .rendered else { throw MathRenderError.notRendered }"
        let guardIndex = try #require(renderer.range(of: guardText))
        let pdfIndex = try #require(renderer.range(of: "webView.pdf(configuration:"))
        #expect(renderIndex.upperBound < guardIndex.lowerBound)
        #expect(guardIndex.upperBound < pdfIndex.lowerBound)

        // And no other file may call it.
        for (url, source) in try Self.swiftFiles(under: "Sources/MathPracticeApp")
        where !url.lastPathComponent.hasPrefix("MathRenderer") {
            #expect(!source.contains(".pdf(configuration:"), "\(Self.name(of: url)) bypasses the render gate")
            #expect(!source.contains("createPDF"), "\(Self.name(of: url)) bypasses the render gate")
        }
    }

    // MARK: - Reviewer criterion: KaTeX is local, and it is the only engine

    @Test("The rendering path reaches no remote host")
    func renderingIsFullyLocal() throws {
        for (url, source) in try Self.swiftFiles(under: "Sources/MathPracticeApp") {
            #expect(!source.contains("https://"), "\(Self.name(of: url)) references a remote URL")
            #expect(!source.contains("cdn."), "\(Self.name(of: url)) references a CDN")
        }
    }

    @Test("KaTeX ships in the bundle, engine and fonts alike")
    func katexIsBundled() throws {
        let katex = Self.repositoryRoot.appendingPathComponent("Sources/MathPracticeApp/Resources/katex")
        let manager = FileManager.default
        #expect(manager.fileExists(atPath: katex.appendingPathComponent("katex.min.js").path))
        #expect(manager.fileExists(atPath: katex.appendingPathComponent("katex.min.css").path))

        let fonts = try manager.contentsOfDirectory(atPath: katex.appendingPathComponent("fonts").path)
            .filter { $0.hasSuffix(".woff2") }
        #expect(fonts.count >= 20, "expected the full KaTeX woff2 set, found \(fonts.count)")

        // Every @font-face the stylesheet declares must have its file present.
        let css = try String(contentsOf: katex.appendingPathComponent("katex.min.css"), encoding: .utf8)
        let referenced = css.components(separatedBy: "url(fonts/").dropFirst().compactMap { fragment in
            fragment.split(separator: ")").first.map(String.init)
        }
        #expect(!referenced.isEmpty)
        for font in Set(referenced) {
            #expect(fonts.contains(font), "katex.min.css references '\(font)', which is not bundled")
        }
    }

    @Test("MathML is not used anywhere — KaTeX is the only engine")
    func katexIsTheOnlyEngine() throws {
        for (url, source) in try Self.swiftFiles(under: "Sources/MathPracticeApp") {
            #expect(!source.contains("MathML"), "\(Self.name(of: url)) mentions MathML; the decision was KaTeX only")
            #expect(!source.contains("<math"), "\(Self.name(of: url)) emits MathML markup")
        }
    }

    // MARK: - Reviewer criterion: PDF export has no iOS conformance

    @Test("MacWorksheetExporter is the only WorksheetExporting conformance")
    func exportHasOneConformance() throws {
        var conformances: [String] = []
        for (url, source) in try Self.swiftFiles(under: "Sources/MathPracticeApp")
        where source.contains(": WorksheetExporting {") {
            conformances.append(Self.name(of: url))
        }
        #expect(conformances == ["Sources/MathPracticeApp/Export/macOS/MacWorksheetExporter.swift"])
    }

    @Test("The platform gate is folder-based, not preprocessor-based")
    func exportGateIsStructural() throws {
        let project = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("project.yml"),
            encoding: .utf8
        )
        #expect(project.contains("\"Export/macOS/**\""), "the iOS target must exclude Export/macOS")
        #expect(project.contains("\"Export/iOS/**\""), "the macOS target must exclude Export/iOS")

        // Both installers exist, with the same entry point, so no view branches on platform.
        for platform in ["macOS", "iOS"] {
            let installer = Self.repositoryRoot
                .appendingPathComponent("Sources/MathPracticeApp/Export/\(platform)/WorksheetExporterInstaller.swift")
            let source = try String(contentsOf: installer, encoding: .utf8)
            #expect(source.contains("static func make() -> (any WorksheetExporting)?"))
        }

        // And no view body reaches for the preprocessor to decide whether export exists.
        for (url, source) in try Self.swiftFiles(under: "Sources/MathPracticeApp/Views") {
            #expect(!source.contains("#if os("), "\(Self.name(of: url)) branches on the platform in a view")
        }
    }
}
