//  DashboardView.swift
//  The progress matrix: topic x sub-type x difficulty. Every number here is folded out of
//  the event stream on the spot — nothing on this screen is stored.

import MathPracticeCore
import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            let matrix = model.dashboard
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summary(matrix)
                    if matrix.totalAttempts == 0 {
                        ContentUnavailableView(
                            "No attempts yet",
                            systemImage: "chart.bar",
                            description: Text("Work a few problems and this fills in.")
                        )
                        .padding(.top, 40)
                    } else {
                        matrixTable(matrix)
                    }
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }

    private func summary(_ matrix: DashboardMatrix) -> some View {
        HStack(spacing: 24) {
            stat("Attempts", "\(matrix.totalAttempts)")
            stat("Correct", "\(matrix.totalCorrect)")
            stat("Accuracy", percentage(overallAccuracy(matrix)))
        }
    }

    private func overallAccuracy(_ matrix: DashboardMatrix) -> Double? {
        guard matrix.totalAttempts > 0 else { return nil }
        return Double(matrix.totalCorrect) / Double(matrix.totalAttempts)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.monospacedDigit())
        }
    }

    private func matrixTable(_ matrix: DashboardMatrix) -> some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Sub-type").font(.caption.bold())
                    Text("Level").font(.caption.bold())
                    ForEach(matrix.difficulties, id: \.self) { difficulty in
                        Text("d\(difficulty)").font(.caption.bold())
                    }
                    Text("Overall").font(.caption.bold())
                }
                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(matrix.rows, id: \.key) { row in
                    GridRow {
                        Text(model.registry.displayName(for: row.key))
                        Text("\(row.currentLevel)").monospacedDigit()
                        ForEach(matrix.difficulties, id: \.self) { difficulty in
                            cell(row.cell(atDifficulty: difficulty))
                        }
                        Text(percentage(row.accuracy)).monospacedDigit()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func cell(_ cell: DashboardCell?) -> some View {
        Group {
            if let cell, cell.attempts > 0 {
                Text("\(cell.correct)/\(cell.attempts)")
                    .monospacedDigit()
                    .foregroundStyle(tint(for: cell.accuracy))
            } else {
                Text("·").foregroundStyle(.tertiary)
            }
        }
    }

    /// Weak areas should be findable at a glance — that is the whole point of the matrix.
    private func tint(for accuracy: Double?) -> Color {
        guard let accuracy else { return .secondary }
        switch accuracy {
        case ..<0.5: return .red
        case ..<0.8: return .orange
        default: return .green
        }
    }

    private func percentage(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }
}
