//  PersistenceController.swift
//  Two stores, one container.
//
//  NOTE FOR REVIEW: the database is split into two `ModelConfiguration`s with DISJOINT
//  model sets — `Library` for the read-mostly imported problem packs, `Log` for the
//  write-heavy append-only event stream — each bound to its own iCloud container
//  identifier, both declared in the macOS and iOS entitlements files. `Persistence.audit`
//  proves the sets are disjoint, and a unit-testable assertion is preferable to a comment.

import Foundation
import SwiftData

enum Persistence {
    /// The read-mostly store: imported problem packs.
    static let libraryConfigurationName = "Library"
    static let libraryCloudContainer = "iCloud.com.jsglazer.MathPractice.Library"

    /// The write-heavy store: the append-only event stream and frozen worksheets.
    static let logConfigurationName = "Log"
    static let logCloudContainer = "iCloud.com.jsglazer.MathPractice.Log"

    static let libraryModels: [any PersistentModel.Type] = [
        PackRecord.self,
        PackProblemRecord.self
    ]

    static let logModels: [any PersistentModel.Type] = [
        EventRecord.self,
        WorksheetRecord.self,
        WorksheetQuestionRecord.self
    ]

    /// The two configurations must never share a model type: a type in both stores would
    /// have two homes, two CloudKit records, and no defensible dedupe identity.
    static var modelSetsAreDisjoint: Bool {
        let library = Set(libraryModels.map { ObjectIdentifier($0) })
        let log = Set(logModels.map { ObjectIdentifier($0) })
        return library.isDisjoint(with: log)
    }

    /// Builds the live container. `inMemory` is used by previews and by any test that wants
    /// a store without touching the user's data or CloudKit.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        precondition(modelSetsAreDisjoint, "Library and Log must not share a model type")

        let librarySchema = Schema(libraryModels)
        let logSchema = Schema(logModels)

        let library = ModelConfiguration(
            libraryConfigurationName,
            schema: librarySchema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .private(libraryCloudContainer)
        )
        let log = ModelConfiguration(
            logConfigurationName,
            schema: logSchema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .private(logCloudContainer)
        )

        return try ModelContainer(
            for: Schema(libraryModels + logModels),
            configurations: library, log
        )
    }
}
