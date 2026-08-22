//  KeyView.swift
//  Every problem flagged "Key" from Practice or Sessions, with the note taken about each.

import MathPracticeCore
import SwiftUI

struct KeyView: View {
    @Environment(AppModel.self) private var model
    @State private var noteDrafts: [String: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                if model.keyProblems.isEmpty {
                    ContentUnavailableView(
                        "No key problems yet",
                        systemImage: "star",
                        description: Text("Flag a problem while practising, or from a past session, and it shows up here.")
                    )
                } else {
                    ForEach(model.keyProblems, id: \.problemID) { record in
                        if let problem = record.problem {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(model.registry.displayName(for: problem.practiceKey))
                                    Spacer()
                                    Text("Level \(problem.difficulty)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                MathTextView(latex: problem.promptLatex, minHeight: 44)

                                TextField("Note about this problem", text: noteBinding(for: record.problemID))
                                    .font(.caption)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        model.setKeyNote(noteDrafts[record.problemID] ?? "", for: record.problemID)
                                    }

                                Text("ID \(record.problemID)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    model.removeKey(record.problemID)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Key")
        }
    }

    private func noteBinding(for problemID: String) -> Binding<String> {
        Binding(
            get: { noteDrafts[problemID] ?? model.keyNote(for: problemID) ?? "" },
            set: { noteDrafts[problemID] = $0 }
        )
    }
}
