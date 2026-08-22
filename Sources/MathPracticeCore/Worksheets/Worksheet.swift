//  Worksheet.swift
//  A named, frozen set of problems for offline paper practice.
//
//  Exporting persists the worksheet FIRST and renders the PDF from the persisted record.
//  That is what makes the printed question numbers and the in-app self-report rows the
//  same ordinals by construction rather than by convention: both read `number` off the
//  same frozen list.

import Foundation

/// One numbered question on a worksheet. `number` is 1-based, as printed.
public struct WorksheetQuestion: Hashable, Sendable, Codable, Identifiable {
    public let id: UUID
    public let dedupeKey: String
    /// 0-based storage index. `number` is what the page and the self-report row show.
    public let index: Int
    public let problem: GeneratedProblem

    public var number: Int { index + 1 }

    public init(id: UUID, worksheetID: UUID, index: Int, problem: GeneratedProblem) {
        self.id = id
        self.index = index
        self.problem = problem
        self.dedupeKey = DedupeKey.worksheetQuestion(worksheetID: worksheetID, questionIndex: index)
    }

    /// Rebuilds a question read back from storage.
    public init(id: UUID, dedupeKey: String, index: Int, problem: GeneratedProblem) {
        self.id = id
        self.dedupeKey = dedupeKey
        self.index = index
        self.problem = problem
    }
}

/// A named worksheet, e.g. "Derivs 0821".
public struct Worksheet: Hashable, Sendable, Codable, Identifiable {
    public let id: UUID
    public let dedupeKey: String
    public let name: String
    public let createdAt: Date
    public let questions: [WorksheetQuestion]

    public init(id: UUID, name: String, createdAt: Date, problems: [GeneratedProblem]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.dedupeKey = DedupeKey.worksheet(worksheetID: id)
        self.questions = problems.enumerated().map { index, problem in
            WorksheetQuestion(
                id: UUID(uuidString: Worksheet.questionUUIDString(worksheetID: id, index: index)) ?? UUID(),
                worksheetID: id,
                index: index,
                problem: problem
            )
        }
    }

    /// Rebuilds a worksheet read back from storage.
    public init(id: UUID, dedupeKey: String, name: String, createdAt: Date, questions: [WorksheetQuestion]) {
        self.id = id
        self.dedupeKey = dedupeKey
        self.name = name
        self.createdAt = createdAt
        self.questions = questions
    }

    public func question(number: Int) -> WorksheetQuestion? {
        questions.first { $0.number == number }
    }

    /// Derives each question's UUID from the worksheet UUID and its index, so a worksheet
    /// built twice from the same inputs — on two devices, from the same export — produces
    /// identical question identities rather than two colliding sets.
    private static func questionUUIDString(worksheetID: UUID, index: Int) -> String {
        var bytes = withUnsafeBytes(of: worksheetID.uuid) { Array($0) }
        let indexBytes = withUnsafeBytes(of: UInt32(truncatingIfNeeded: index).bigEndian) { Array($0) }
        for offset in 0..<indexBytes.count {
            bytes[bytes.count - indexBytes.count + offset] ^= indexBytes[offset]
        }
        let hex = bytes.map { String(format: "%02X", $0) }.joined()
        let ranges = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32]
        return ranges
            .map { String(Array(hex)[$0]) }
            .joined(separator: "-")
    }
}

/// The device-supplied details every appended event needs: who wrote it, when, where in
/// that device's ordinal sequence it sits, and the identifiers to give the new records.
///
/// Bundled into one value so the shell decides all of it in one place — and so core takes
/// no clock, no device lookup and no UUID source of its own.
public struct EventStamping: Hashable, Sendable {
    public let deviceID: DeviceID
    public let firstOrdinal: Int
    public let timestamp: Date
    public let identifiers: [UUID]

    public init(deviceID: DeviceID, firstOrdinal: Int, timestamp: Date, identifiers: [UUID]) {
        self.deviceID = deviceID
        self.firstOrdinal = firstOrdinal
        self.timestamp = timestamp
        self.identifiers = identifiers
    }
}

/// Builds the worksheet a self-report session reads back.
public enum WorksheetBuilder {
    /// Freezes `problems` into a named worksheet. The order given is the printed order.
    public static func make(
        id: UUID,
        name: String,
        createdAt: Date,
        problems: [GeneratedProblem]
    ) -> Worksheet {
        Worksheet(id: id, name: name, createdAt: createdAt, problems: problems)
    }

    /// The events a completed self-report session appends. One event per answered question,
    /// each carrying the worksheet id and the printed question number.
    public static func selfReportEvents(
        worksheet: Worksheet,
        outcomes: [Int: AttemptOutcome],
        stamping: EventStamping
    ) -> [PracticeEvent] {
        let answered = outcomes.keys.sorted()
        return answered.enumerated().compactMap { position, number in
            guard let outcome = outcomes[number],
                  let question = worksheet.question(number: number),
                  position < stamping.identifiers.count else { return nil }
            return PracticeEvent(
                id: stamping.identifiers[position],
                createdAt: stamping.timestamp,
                deviceID: stamping.deviceID,
                ordinal: stamping.firstOrdinal + position,
                key: question.problem.practiceKey,
                difficulty: question.problem.difficulty,
                templateID: question.problem.templateID,
                problemID: question.problem.problemID,
                seed: question.problem.seed,
                kind: .worksheetSelfReport(
                    outcome,
                    worksheetID: worksheet.id,
                    questionNumber: number
                )
            )
        }
    }
}
