//  PracticeView.swift
//  The drill loop. The app never asks for the answer, never grades, and never shows an
//  input field — the only things it accepts are "show me more" and "I got it right/wrong".

import MathPracticeCore
import SwiftUI

struct PracticeView: View {
    @Environment(AppModel.self) private var model
    @State private var showSkipPrompt = false
    @State private var skipNote = ""
    @State private var showMarkdownSheet = false
    @State private var keyNoteDraft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What to practise") {
                    // One consolidated line: mix controls, then the problem's ID and note.
                    SelectionControls {
                        if let problem = model.currentProblem {
                            problemAccessory(for: problem)
                        }
                    }
                    ClassPicker(
                        title: "Class",
                        nilLabel: defaultClassLabel,
                        selection: Binding(
                            get: { model.sessionClassTag },
                            set: { model.setSessionClassTag($0) }
                        )
                    )
                }

                if let problem = model.currentProblem {
                    Section {
                        Text(problem.instruction)
                            .font(.system(size: 24))
                            .foregroundStyle(.primary)
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
                        HStack(alignment: .top) {
                            // The saved note, rendered as Markdown.
                            if let note = model.keyNote(for: problem.problemID), !note.isEmpty {
                                MarkdownNoteText(note: note)
                                    .font(.callout)
                            }
                            Spacer()
                            Button {
                                model.toggleKey(for: problem)
                                keyNoteDraft = model.keyNote(for: problem.problemID) ?? ""
                            } label: {
                                Label(
                                    model.isKey(problem.problemID) ? "Key" : "Mark as key",
                                    systemImage: model.isKey(problem.problemID) ? "star.fill" : "star"
                                )
                            }
                            .buttonStyle(.plain)
                            .font(.title3)
                            .foregroundStyle(model.isKey(problem.problemID) ? .yellow : .secondary)
                        }
                    }

                    Section("Reveal") {
                        HStack {
                            Button("Show answer", action: model.revealAnswer)
                                .disabled(model.revealState.answerShown)
                            Button(stepButtonTitle, action: model.revealStep)
                                .disabled(!model.canRevealMoreSteps)
                            Button(model.solutionHidden ? "Show steps" : "Hide steps", action: model.toggleSolutionHidden)
                                .disabled(!model.hasRevealedSolution)
                            Spacer()
                            Button("View as Markdown", systemImage: "doc.on.clipboard") {
                                showMarkdownSheet = true
                            }
                        }
                        .buttonStyle(.bordered)

                        // Answer and steps render together in one WKWebView, so a person can
                        // select and copy the whole worked solution in one drag rather than
                        // hunting through a separate box per step.
                        if !solutionBlocks.isEmpty, !model.solutionHidden {
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
            .onChange(of: model.currentProblem?.problemID, initial: true) { _, problemID in
                keyNoteDraft = problemID.flatMap(model.keyNote) ?? ""
            }
            .toolbar {
                // The version label rides alongside Skip in the same primary-action slot, but
                // must not pick up the automatic Liquid Glass pill background that toolbar
                // controls get on macOS/iOS 26 — that's the "circle" around it. Only the pill
                // itself is opted out; Skip keeps its normal button chrome.
                if #available(macOS 26.0, iOS 26.0, *) {
                    ToolbarItem(placement: .primaryAction) {
                        Text(appVersionString)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Text(appVersionString)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Skip") { showSkipPrompt = true }
                        .disabled(model.currentProblem == nil)
                }
            }
            .alert("Skip this problem?", isPresented: $showSkipPrompt) {
                TextField("Note (optional)", text: $skipNote)
                Button("Skip") {
                    model.skip(note: skipNote.trimmingCharacters(in: .whitespacesAndNewlines))
                    skipNote = ""
                }
                Button("Cancel", role: .cancel) { skipNote = "" }
            }
            .sheet(isPresented: $showMarkdownSheet) {
                MarkdownSolutionView(markdown: markdownText)
            }
        }
    }

    /// The problem's ID and an inline note field, riding at the end of the selection row.
    /// The ID is written down for troubleshooting: quoting it is enough to pull this exact
    /// problem instance back up later.
    @ViewBuilder
    private func problemAccessory(for problem: GeneratedProblem) -> some View {
        Text("ID \(problem.problemID)")
            .font(.body.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .fixedSize()
        NoteField(text: $keyNoteDraft) {
            model.setNote(keyNoteDraft, for: problem)
        }
        .frame(minWidth: 140, maxWidth: 280)
    }

    private var defaultClassLabel: String {
        model.defaultClassName.isEmpty ? "Default (no class)" : "Default (\(model.defaultClassName))"
    }

    /// Once the answer is out there is nothing left to gate, so the label says so.
    private var stepButtonTitle: String {
        model.revealState.answerShown ? "Show full solution" : "Show next step"
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "v\(version)"
    }

    /// The current problem, its answer and its revealed steps, formatted as Markdown with
    /// math wrapped in single dollar signs — Obsidian's inline-math syntax — so the whole
    /// thing can be pasted straight into a note.
    private var markdownText: String {
        guard let problem = model.currentProblem else { return "" }
        var lines: [String] = []
        lines.append("### \(model.registry.displayName(for: problem.practiceKey)) · Level \(problem.difficulty)")
        lines.append("")
        lines.append("**Problem:** \(problem.instruction)")
        lines.append("")
        lines.append("$\(problem.promptLatex)$")

        for (index, step) in model.revealedSteps.enumerated() {
            lines.append("")
            lines.append("**Step \(index + 1) · \(step.title)**")
            lines.append("$\(step.latex)$")
        }
        if let answer = model.revealedAnswer {
            lines.append("")
            lines.append("**Answer:** $\(answer)$")
        }
        return lines.joined(separator: "\n")
    }

    /// Steps before the answer, so the full solution reads as a derivation ending in its
    /// result rather than leading with it.
    private var solutionBlocks: [MathBlock] {
        var blocks: [MathBlock] = []
        for (index, step) in model.revealedSteps.enumerated() {
            blocks.append(MathBlock(latex: step.latex, label: "Step \(index + 1) · \(step.title)"))
        }
        if let answer = model.revealedAnswer {
            blocks.append(MathBlock(latex: answer, label: "Answer"))
        }
        return blocks
    }
}
