//  PracticeView.swift
//  The drill loop. The app never asks for the answer, never grades, and never shows an
//  input field — the only things it accepts are "show me more" and "I got it right/wrong".

import MathPracticeCore
import SwiftUI

struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSkipPrompt = false
    @State private var skipNote = ""

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
                        MathTextView(latex: problem.promptLatex, minHeight: 76)
                    } header: {
                        HStack {
                            Text("Problem")
                            Spacer()
                            Text(model.registry.displayName(for: problem.practiceKey))
                            Text("· Level \(problem.difficulty)")
                        }
                        .font(.caption)
                    } footer: {
                        // Written down for troubleshooting: quoting this ID is enough to
                        // pull this exact problem instance back up later.
                        Text("ID \(problem.problemID)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }

                    Section("Reveal") {
                        HStack {
                            Button("Show answer", action: model.revealAnswer)
                                .disabled(model.revealState.answerShown)
                            Button(stepButtonTitle, action: model.revealStep)
                                .disabled(!model.canRevealMoreSteps)
                        }
                        .buttonStyle(.bordered)

                        // Answer and steps render together in one WKWebView, so a person can
                        // select and copy the whole worked solution in one drag rather than
                        // hunting through a separate box per step.
                        if !solutionBlocks.isEmpty {
                            MathTextView(blocks: solutionBlocks, minHeight: 60)
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
                Button("Skip") { showSkipPrompt = true }
                    .disabled(model.currentProblem == nil)
            }
            .alert("Skip this problem?", isPresented: $showSkipPrompt) {
                TextField("Note (optional)", text: $skipNote)
                Button("Skip") {
                    model.skip(note: skipNote.trimmingCharacters(in: .whitespacesAndNewlines))
                    skipNote = ""
                }
                Button("Cancel", role: .cancel) { skipNote = "" }
            }
        }
    }

    /// Once the answer is out there is nothing left to gate, so the label says so.
    private var stepButtonTitle: String {
        model.revealState.answerShown ? "Show full solution" : "Show next step"
    }

    private var solutionBlocks: [MathBlock] {
        var blocks: [MathBlock] = []
        if let answer = model.revealedAnswer {
            blocks.append(MathBlock(latex: answer, label: "Answer"))
        }
        for (index, step) in model.revealedSteps.enumerated() {
            blocks.append(MathBlock(latex: step.latex, label: "Step \(index + 1) · \(step.title)"))
        }
        return blocks
    }
}
