//  PracticeView.swift
//  The drill loop. The app never asks for the answer, never grades, and never shows an
//  input field — the only things it accepts are "show me more" and "I got it right/wrong".

import MathPracticeCore
import SwiftUI

struct PracticeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Form {
                Section("What to practise") {
                    SelectionControls()
                }

                if let problem = model.currentProblem {
                    Section {
                        Text(problem.instruction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        MathTextView(latex: problem.promptLatex, height: 76)
                    } header: {
                        HStack {
                            Text("Problem")
                            Spacer()
                            Text(model.registry.displayName(for: problem.practiceKey))
                            Text("· Level \(problem.difficulty)")
                        }
                        .font(.caption)
                    }

                    Section("Reveal") {
                        HStack {
                            Button("Show answer", action: model.revealAnswer)
                                .disabled(model.revealState.answerShown)
                            Button(stepButtonTitle, action: model.revealStep)
                                .disabled(!model.canRevealMoreSteps)
                        }
                        .buttonStyle(.bordered)

                        if let answer = model.revealedAnswer {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Answer").font(.caption).foregroundStyle(.secondary)
                                MathTextView(latex: answer)
                            }
                        }

                        ForEach(Array(model.revealedSteps.enumerated()), id: \.offset) { index, step in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Step \(index + 1) · \(step.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                MathTextView(latex: step.latex, height: 54)
                            }
                        }
                    }

                    Section("How did it go?") {
                        HStack(spacing: 12) {
                            Button {
                                model.record(.correct)
                            } label: {
                                Label("Right", systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.green)

                            Button {
                                model.record(.incorrect)
                            } label: {
                                Label("Wrong", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .tint(.red)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Section {
                        Button("Start practising", action: model.nextProblem)
                    }
                }

                if let error = model.lastError {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Practice")
            .toolbar {
                Button("Skip", action: model.nextProblem)
                    .disabled(model.currentProblem == nil)
            }
        }
    }

    /// Once the answer is out there is nothing left to gate, so the label says so.
    private var stepButtonTitle: String {
        model.revealState.answerShown ? "Show full solution" : "Show next step"
    }
}
