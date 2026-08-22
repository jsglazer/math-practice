//  LibraryModels.swift
//  The `Library` store: imported problem packs, read-mostly.
//
//  NOTE FOR REVIEW: as in `LogModels.swift`, no `@Attribute(.unique)`, no `#Unique`, every
//  property optional or defaulted, every relationship optional with an explicit inverse.
//  No type in this file appears in the `Log` configuration, and no `Log` type appears here.

import Foundation
import MathPracticeCore
import SwiftData

/// An imported pack, identified by `(identifier, version)`.
///
/// A superseded pack is hidden, never deleted: the append-only attempt log references
/// problems from earlier versions and nothing in the log may be orphaned.
@Model
final class PackRecord {
    var dedupeKey: String = ""
    var identifier: String = ""
    var version: Int = 0
    var title: String = ""
    var topicID: String = ""
    var createdAt: Date = Date.distantPast
    var isHidden: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \PackProblemRecord.pack)
    var problems: [PackProblemRecord]? = []

    init(pack: ProblemPack, importedAt: Date) {
        dedupeKey = pack.dedupeKey
        identifier = pack.identifier
        version = pack.version
        title = pack.title
        topicID = pack.topicID.rawValue
        createdAt = importedAt
        isHidden = false
        problems = []
    }

    var installed: InstalledPack {
        InstalledPack(identifier: identifier, version: version, isHidden: isHidden)
    }
}

/// One problem inside an imported pack.
@Model
final class PackProblemRecord {
    var dedupeKey: String = ""
    var index: Int = 0
    var createdAt: Date = Date.distantPast
    var problemData: Data?

    var pack: PackRecord?

    init(problem: GeneratedProblem, packIdentifier: String, version: Int, index: Int, importedAt: Date) {
        dedupeKey = DedupeKey.packProblem(identifier: packIdentifier, version: version, problemIndex: index)
        self.index = index
        createdAt = importedAt
        problemData = try? JSONEncoder().encode(problem)
    }

    var problem: GeneratedProblem? {
        guard let problemData else { return nil }
        return try? JSONDecoder().decode(GeneratedProblem.self, from: problemData)
    }
}
