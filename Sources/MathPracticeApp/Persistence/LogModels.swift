//  LogModels.swift
//  The `Log` store: the append-only event stream and the frozen worksheets.
//
//  NOTE FOR REVIEW: no model in this file uses `@Attribute(.unique)` or `#Unique`. SwiftData
//  with CloudKit does not support unique constraints, so uniqueness lives in `dedupeKey`
//  and is enforced by `DeduplicationService`. Every property is optional or defaulted, and
//  every relationship is optional with an explicit inverse — both CloudKit requirements.

import Foundation
import MathPracticeCore
import SwiftData

/// One immutable entry in the event stream. Never mutated after insert; deleted only by
/// the dedup pass collapsing a sync-level duplicate.
@Model
final class EventRecord {
    var dedupeKey: String = ""
    var eventID: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var deviceIdentifier: String = ""
    var ordinal: Int = 0

    var topicID: String?
    var subTypeID: String?
    var difficulty: Int?
    var templateID: String?
    var problemID: String?

    var kindTag: String = ""
    var outcomeRaw: String?
    var skipNote: String?
    var overrideLevel: Int?
    var worksheetID: UUID?
    var questionNumber: Int?
    var stepUpThreshold: Int?
    var stepDownThreshold: Int?
    var holdPeriod: Int?

    init(event: PracticeEvent) {
        dedupeKey = event.dedupeKey
        eventID = event.id
        createdAt = event.createdAt
        deviceIdentifier = event.deviceID.rawValue
        ordinal = event.ordinal
        topicID = event.key?.topic.rawValue
        subTypeID = event.key?.subType.rawValue
        difficulty = event.difficulty
        templateID = event.templateID?.rawValue
        problemID = event.problemID
        kindTag = event.kind.tag

        switch event.kind {
        case let .attempt(outcome):
            outcomeRaw = outcome.rawValue
        case let .worksheetSelfReport(outcome, worksheet, number):
            outcomeRaw = outcome.rawValue
            worksheetID = worksheet
            questionNumber = number
        case let .skipped(note):
            skipNote = note
        case let .manualLevelOverride(level):
            overrideLevel = level
        case let .ladderConfiguration(configuration):
            stepUpThreshold = configuration.stepUpThreshold
            stepDownThreshold = configuration.stepDownThreshold
            holdPeriod = configuration.holdPeriod
        }
    }

    /// Rebuilds the pure event every fold in `MathPracticeCore` operates on.
    /// Returns `nil` for a row whose kind cannot be reconstructed — a forward-compatible
    /// row written by a newer version is skipped rather than crashing the fold.
    var practiceEvent: PracticeEvent? {
        guard let kind = decodedKind else { return nil }
        var key: PracticeKey?
        if let topicID, let subTypeID {
            key = PracticeKey(topic: TopicID(topicID), subType: SubTypeID(subTypeID))
        }
        return PracticeEvent(
            id: eventID,
            dedupeKey: dedupeKey,
            createdAt: createdAt,
            deviceID: DeviceID(deviceIdentifier),
            ordinal: ordinal,
            key: key,
            difficulty: difficulty,
            templateID: templateID.map { TemplateID($0) },
            problemID: problemID,
            kind: kind
        )
    }

    private var decodedKind: PracticeEventKind? {
        switch kindTag {
        case "attempt":
            guard let raw = outcomeRaw, let outcome = AttemptOutcome(rawValue: raw) else { return nil }
            return .attempt(outcome)
        case "worksheet-report":
            guard let raw = outcomeRaw,
                  let outcome = AttemptOutcome(rawValue: raw),
                  let worksheetID,
                  let questionNumber else { return nil }
            return .worksheetSelfReport(outcome, worksheetID: worksheetID, questionNumber: questionNumber)
        case "skip":
            return .skipped(note: skipNote)
        case "level-override":
            guard let overrideLevel else { return nil }
            return .manualLevelOverride(level: overrideLevel)
        case "ladder-config":
            guard let stepUpThreshold, let stepDownThreshold, let holdPeriod else { return nil }
            return .ladderConfiguration(LadderConfiguration(
                stepUpThreshold: stepUpThreshold,
                stepDownThreshold: stepDownThreshold,
                holdPeriod: holdPeriod
            ))
        default:
            return nil
        }
    }
}

/// A named worksheet with its frozen, ordered question list.
@Model
final class WorksheetRecord {
    var dedupeKey: String = ""
    var worksheetID: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.distantPast

    @Relationship(deleteRule: .cascade, inverse: \WorksheetQuestionRecord.worksheet)
    var questions: [WorksheetQuestionRecord]? = []

    init(worksheet: Worksheet) {
        dedupeKey = worksheet.dedupeKey
        worksheetID = worksheet.id
        name = worksheet.name
        createdAt = worksheet.createdAt
        questions = []
    }
}

/// One frozen question. The problem is stored as encoded JSON so a later template revision
/// can never change what a printed worksheet says.
@Model
final class WorksheetQuestionRecord {
    var dedupeKey: String = ""
    var questionID: UUID = UUID()
    var index: Int = 0
    var createdAt: Date = Date.distantPast
    var problemData: Data?

    var worksheet: WorksheetRecord?

    init(question: WorksheetQuestion, createdAt: Date) {
        dedupeKey = question.dedupeKey
        questionID = question.id
        index = question.index
        self.createdAt = createdAt
        problemData = try? JSONEncoder().encode(question.problem)
    }

    var problem: GeneratedProblem? {
        guard let problemData else { return nil }
        return try? JSONDecoder().decode(GeneratedProblem.self, from: problemData)
    }

    var worksheetQuestion: WorksheetQuestion? {
        guard let problem else { return nil }
        return WorksheetQuestion(id: questionID, dedupeKey: dedupeKey, index: index, problem: problem)
    }
}
