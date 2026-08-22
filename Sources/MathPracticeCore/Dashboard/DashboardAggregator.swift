//  DashboardAggregator.swift
//  The progress matrix: topic x sub-type x difficulty, folded out of the event stream.
//
//  Like the ladder, nothing here is stored. The dashboard is a pure function of the
//  events, so it can never disagree with the log it is drawn from.

/// One cell of the matrix.
public struct DashboardCell: Hashable, Sendable {
    public let key: PracticeKey
    public let difficulty: Int
    public let attempts: Int
    public let correct: Int

    public var incorrect: Int { attempts - correct }

    /// Accuracy in 0...1, or `nil` when the cell has never been attempted.
    public var accuracy: Double? {
        attempts == 0 ? nil : Double(correct) / Double(attempts)
    }
}

/// A row of the matrix: one `(topic, sub-type)` across every difficulty seen.
public struct DashboardRow: Hashable, Sendable {
    public let key: PracticeKey
    public let cells: [DashboardCell]
    public let attempts: Int
    public let correct: Int
    public let currentLevel: Int

    public var accuracy: Double? {
        attempts == 0 ? nil : Double(correct) / Double(attempts)
    }

    public func cell(atDifficulty difficulty: Int) -> DashboardCell? {
        cells.first { $0.difficulty == difficulty }
    }
}

/// The whole dashboard.
public struct DashboardMatrix: Hashable, Sendable {
    public let rows: [DashboardRow]
    public let difficulties: [Int]

    public func row(for key: PracticeKey) -> DashboardRow? {
        rows.first { $0.key == key }
    }

    public var totalAttempts: Int { rows.reduce(0) { $0 + $1.attempts } }
    public var totalCorrect: Int { rows.reduce(0) { $0 + $1.correct } }
}

public enum DashboardAggregator {
    /// Builds the matrix for `keys`, in the order given, from the event stream.
    ///
    /// Keys with no attempts are still emitted, so a new topic shows up as empty rather
    /// than invisible — which is what makes "where am I weak" answerable.
    public static func aggregate(
        events: [PracticeEvent],
        keys: [PracticeKey],
        ladder: LadderSnapshot
    ) -> DashboardMatrix {
        var tallies: [PracticeKey: [Int: (attempts: Int, correct: Int)]] = [:]
        var difficultiesSeen: Set<Int> = []

        for event in events {
            guard let key = event.key,
                  let outcome = event.kind.outcome,
                  let difficulty = event.difficulty else { continue }
            difficultiesSeen.insert(difficulty)
            var byDifficulty = tallies[key] ?? [:]
            var tally = byDifficulty[difficulty] ?? (0, 0)
            tally.attempts += 1
            if outcome.isCorrect { tally.correct += 1 }
            byDifficulty[difficulty] = tally
            tallies[key] = byDifficulty
        }

        let difficulties = difficultiesSeen.sorted()
        let rows = keys.map { key -> DashboardRow in
            let byDifficulty = tallies[key] ?? [:]
            let cells = difficulties.map { difficulty -> DashboardCell in
                let tally = byDifficulty[difficulty] ?? (attempts: 0, correct: 0)
                return DashboardCell(
                    key: key,
                    difficulty: difficulty,
                    attempts: tally.attempts,
                    correct: tally.correct
                )
            }
            return DashboardRow(
                key: key,
                cells: cells,
                attempts: cells.reduce(0) { $0 + $1.attempts },
                correct: cells.reduce(0) { $0 + $1.correct },
                currentLevel: ladder.level(for: key)
            )
        }
        return DashboardMatrix(rows: rows, difficulties: difficulties)
    }
}
