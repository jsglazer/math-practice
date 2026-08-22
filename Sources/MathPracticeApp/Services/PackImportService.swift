//  PackImportService.swift
//  Importing LLM-authored problem packs from a file.
//
//  A pack is validated wholesale and rejected in full on any single failure — it is never
//  partially imported. Re-importing the same `(identifier, version)` is a no-op; a higher
//  version supersedes and HIDES the earlier one without deleting it, because the append-only
//  attempt log references problems from that earlier version.

import Foundation
import MathPracticeCore
import SwiftData

/// What an import did, for the UI to report.
enum PackImportResult: Equatable {
    case installed(identifier: String, version: Int, problems: Int)
    case superseded(identifier: String, version: Int, problems: Int, hidden: [Int])
    case alreadyInstalled(identifier: String, version: Int)
    case refusedOlderVersion(identifier: String, installedVersion: Int)
}

enum PackImportError: Error, LocalizedError {
    case unreadable(underlying: String)
    case malformed(underlying: String)
    case invalid(PackValidationFailure)

    var errorDescription: String? {
        switch self {
        case let .unreadable(underlying): return "Could not read the pack file: \(underlying)"
        case let .malformed(underlying): return "The pack file is not valid JSON: \(underlying)"
        case let .invalid(failure): return "The pack was rejected: \(failure.description)"
        }
    }
}

@MainActor
final class PackImportService {
    private let context: ModelContext
    private let registry: TopicRegistry
    private let clock: () -> Date

    init(context: ModelContext, registry: TopicRegistry, clock: @escaping () -> Date = Date.init) {
        self.context = context
        self.registry = registry
        self.clock = clock
    }

    /// Reads, validates and imports a pack file.
    func importPack(at url: URL) throws -> PackImportResult {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PackImportError.unreadable(underlying: error.localizedDescription)
        }

        let pack: ProblemPack
        do {
            pack = try JSONDecoder().decode(ProblemPack.self, from: data)
        } catch {
            throw PackImportError.malformed(underlying: error.localizedDescription)
        }

        return try install(pack)
    }

    /// The store-touching half. Validation and the decision both happen before this writes.
    func install(_ pack: ProblemPack) throws -> PackImportResult {
        let validated: ValidatedPack
        switch PackValidator.validate(pack, registry: registry) {
        case let .success(result):
            validated = result
        case let .failure(failure):
            throw PackImportError.invalid(failure)
        }

        let existing = (try? context.fetch(FetchDescriptor<PackRecord>())) ?? []
        let decision = PackImportPlanner.plan(
            candidate: pack,
            installed: existing.map(\.installed)
        )

        switch decision {
        case let .noOp(identifier, version):
            return .alreadyInstalled(identifier: identifier, version: version)

        case let .supersededByNewer(installedVersion):
            return .refusedOlderVersion(identifier: pack.identifier, installedVersion: installedVersion)

        case .install:
            let count = write(validated)
            return .installed(identifier: pack.identifier, version: pack.version, problems: count)

        case let .supersede(hiding):
            for record in existing where record.identifier == pack.identifier && hiding.contains(record.version) {
                // Hidden, never deleted — attempt history still points at these problems.
                record.isHidden = true
            }
            let count = write(validated)
            return .superseded(
                identifier: pack.identifier,
                version: pack.version,
                problems: count,
                hidden: hiding
            )
        }
    }

    /// Writes a validated pack and its problems. Called only after the plan says to.
    private func write(_ validated: ValidatedPack) -> Int {
        let importedAt = clock()
        let record = PackRecord(pack: validated.pack, importedAt: importedAt)
        context.insert(record)

        let problems = validated.problems()
        for (index, problem) in problems.enumerated() {
            let problemRecord = PackProblemRecord(
                problem: problem,
                packIdentifier: validated.pack.identifier,
                version: validated.pack.version,
                index: index,
                importedAt: importedAt
            )
            problemRecord.pack = record
            context.insert(problemRecord)
        }
        try? context.save()
        return problems.count
    }

    /// Every visible imported problem, for the selector to mix in.
    func visibleProblems() -> [GeneratedProblem] {
        let packs = (try? context.fetch(FetchDescriptor<PackRecord>())) ?? []
        return packs
            .filter { !$0.isHidden }
            .flatMap { ($0.problems ?? []).sorted { $0.index < $1.index } }
            .compactMap(\.problem)
    }
}
