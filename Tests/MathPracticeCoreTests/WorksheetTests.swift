//  WorksheetTests.swift
//  The printed-worksheet loop: freeze, number, self-report.
//
//  The property that matters is that printed question numbers and in-app self-report rows
//  are the same ordinals by construction — both read them off one frozen list.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("Worksheets")
struct WorksheetTests {
    let worksheetID = EventFactory.orderedUUID(0x3F)

    func makeProblems(count: Int, seed: UInt64 = 900) throws -> [GeneratedProblem] {
        let selector = ProblemSelector(registry: .standard)
        var generator = RandomSource(seed: seed)
        let request = PracticeRequest(topic: .derivatives, subType: nil, difficulty: .fixed(5))
        return try (0..<count).map { _ in
            try selector.next(request, ladder: DifficultyLadder.fold([]), using: &generator)
        }
    }

    @Test("Questions are numbered from 1 in the order given")
    func questionsAreNumbered() throws {
        let worksheet = WorksheetBuilder.make(
            id: worksheetID,
            name: "Derivs 0821",
            createdAt: EventFactory.base,
            problems: try makeProblems(count: 8)
        )
        #expect(worksheet.questions.map(\.number) == Array(1...8))
        #expect(worksheet.questions.map(\.index) == Array(0..<8))
        #expect(worksheet.question(number: 4)?.index == 3)
        #expect(worksheet.question(number: 0) == nil)
        #expect(worksheet.question(number: 9) == nil)
    }

    @Test("The frozen problems are exactly the ones handed in, in order")
    func problemsAreFrozen() throws {
        let problems = try makeProblems(count: 5)
        let worksheet = WorksheetBuilder.make(
            id: worksheetID,
            name: "Derivs 0821",
            createdAt: EventFactory.base,
            problems: problems
        )
        #expect(worksheet.questions.map(\.problem) == problems)
    }

    @Test("Question dedupe keys are worksheet id plus index")
    func questionDedupeKeys() throws {
        let worksheet = WorksheetBuilder.make(
            id: worksheetID,
            name: "Derivs 0821",
            createdAt: EventFactory.base,
            problems: try makeProblems(count: 3)
        )
        let expected = DedupeKey.worksheetQuestion(worksheetID: worksheetID, questionIndex: 2)
        #expect(worksheet.questions[2].dedupeKey == expected)
        #expect(Set(worksheet.questions.map(\.dedupeKey)).count == 3)
    }

    @Test("Building the same worksheet twice yields the same question identities")
    func questionIdentitiesAreDerived() throws {
        let problems = try makeProblems(count: 6)
        let first = WorksheetBuilder.make(id: worksheetID, name: "A", createdAt: EventFactory.base, problems: problems)
        let second = WorksheetBuilder.make(id: worksheetID, name: "A", createdAt: EventFactory.base, problems: problems)
        #expect(first.questions.map(\.id) == second.questions.map(\.id))
        #expect(Set(first.questions.map(\.id)).count == 6)
    }

    @Test("Self-reports carry the printed question number and the frozen difficulty")
    func selfReportsMatchThePage() throws {
        let problems = try makeProblems(count: 4)
        let worksheet = WorksheetBuilder.make(
            id: worksheetID,
            name: "Derivs 0821",
            createdAt: EventFactory.base,
            problems: problems
        )
        let outcomes: [Int: AttemptOutcome] = [1: .correct, 2: .incorrect, 4: .correct]
        let identifiers = (0..<3).map { EventFactory.uuid(device: "mac", ordinal: $0) }

        let events = WorksheetBuilder.selfReportEvents(
            worksheet: worksheet,
            outcomes: outcomes,
            stamping: EventStamping(
                deviceID: DeviceID("mac"),
                firstOrdinal: 10,
                timestamp: EventFactory.base,
                identifiers: identifiers
            )
        )

        #expect(events.count == 3)
        #expect(events.map(\.ordinal) == [10, 11, 12])
        for (offset, number) in [1, 2, 4].enumerated() {
            guard case let .worksheetSelfReport(outcome, id, reported) = events[offset].kind else {
                Issue.record("expected a worksheet self-report")
                return
            }
            #expect(id == worksheetID)
            #expect(reported == number)
            #expect(outcome == outcomes[number])
            // The recorded key and difficulty come off the frozen question, not the UI.
            let question = try #require(worksheet.question(number: number))
            #expect(events[offset].key == question.problem.practiceKey)
            #expect(events[offset].difficulty == question.problem.difficulty)
        }
    }

    @Test("Worksheet self-reports drive the ladder exactly like in-app attempts")
    func selfReportsFeedTheLadder() throws {
        let key = PracticeKey(topic: .derivatives, subType: .powerRule)
        let problems = try makeProblems(count: 3)
        let worksheet = WorksheetBuilder.make(
            id: worksheetID,
            name: "Derivs 0821",
            createdAt: EventFactory.base,
            problems: problems
        )
        // Report every question correct, but attribute them to one key so the run is a run.
        let events = (0..<3).map { offset in
            PracticeEvent(
                id: EventFactory.uuid(device: "mac", ordinal: offset),
                createdAt: EventFactory.base.addingTimeInterval(TimeInterval(offset)),
                deviceID: DeviceID("mac"),
                ordinal: offset,
                key: key,
                difficulty: 5,
                templateID: worksheet.questions[offset].problem.templateID,
                kind: .worksheetSelfReport(.correct, worksheetID: worksheetID, questionNumber: offset + 1)
            )
        }
        #expect(DifficultyLadder.level(for: key, in: events) == 2)
    }

    @Test("Unanswered questions produce no events")
    func unansweredQuestionsAreSilent() throws {
        let worksheet = WorksheetBuilder.make(
            id: worksheetID,
            name: "Derivs 0821",
            createdAt: EventFactory.base,
            problems: try makeProblems(count: 5)
        )
        let events = WorksheetBuilder.selfReportEvents(
            worksheet: worksheet,
            outcomes: [:],
            stamping: EventStamping(
                deviceID: DeviceID("mac"),
                firstOrdinal: 0,
                timestamp: EventFactory.base,
                identifiers: []
            )
        )
        #expect(events.isEmpty)
    }

    @Test("A worksheet round-trips through JSON")
    func worksheetRoundTrips() throws {
        let worksheet = WorksheetBuilder.make(
            id: worksheetID,
            name: "Derivs 0821",
            createdAt: EventFactory.base,
            problems: try makeProblems(count: 3)
        )
        let data = try JSONEncoder().encode(worksheet)
        #expect(try JSONDecoder().decode(Worksheet.self, from: data) == worksheet)
    }
}
