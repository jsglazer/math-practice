//  KeyView.swift
//  Every problem flagged "Key" from Practice or Sessions, with the note taken about each.

import MathPracticeCore
import SwiftUI
import UniformTypeIdentifiers

struct KeyView: View {
    @Environment(AppModel.self) private var model
    @State private var noteDrafts: [String: String] = [:]
    /// Problems tapped to unstar, dimmed but kept on screen until the page is left — a
    /// slip of the star doesn't remove anything until there's been a chance to undo it.
    @State private var pendingUnstar: Set<String> = []
    @State private var showMarkdownFor: KeyProblemRecord?
    @State private var isExporting = false

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
                        KeyProblemRow(
                            record: record,
                            noteDrafts: $noteDrafts,
                            pendingUnstar: $pendingUnstar,
                            showMarkdownFor: $showMarkdownFor
                        )
                    }
                }
            }
            .navigationTitle("Key")
            .toolbar {
                if model.keyExporter != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Export PDF", systemImage: "square.and.arrow.up") { isExporting = true }
                            .disabled(model.keyProblems.isEmpty)
                    }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: KeyPDFDocument(),
                contentType: .pdf,
                defaultFilename: model.keyExporter?.suggestedFilename ?? "Key Problems.pdf"
            ) { result in
                guard case let .success(url) = result else { return }
                Task { await model.exportKeyProblems(to: url) }
            }
            .sheet(item: $showMarkdownFor) { record in
                if let problem = record.problem {
                    MarkdownSolutionView(
                        markdown: "$\(problem.promptLatex)$",
                        blocks: [MathBlock(latex: problem.promptLatex)]
                    )
                }
            }
            .onDisappear(perform: commitPendingUnstars)
        }
    }

    private func toggleUnstar(_ problemID: String) {
        if pendingUnstar.contains(problemID) {
            pendingUnstar.remove(problemID)
        } else {
            pendingUnstar.insert(problemID)
        }
    }

    private func commitPendingUnstars() {
        for problemID in pendingUnstar {
            model.removeKey(problemID)
        }
        pendingUnstar.removeAll()
    }
}

/// One flagged problem: its equation, its note, and the ID/clipboard/star row below it.
/// Split out of `KeyView`'s `ForEach` so the type-checker has a small enough expression to
/// solve — the inline version above forced it to check one enormous view-builder closure
/// and reported an unrelated `ForEach` overload error instead of the real one.
private struct KeyProblemRow: View {
    @Environment(AppModel.self) private var model
    let record: KeyProblemRecord
    @Binding var noteDrafts: [String: String]
    @Binding var pendingUnstar: Set<String>
    @Binding var showMarkdownFor: KeyProblemRecord?

    var body: some View {
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

                TextField("Note about this problem", text: noteBinding)
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.setKeyNote(noteDrafts[record.problemID] ?? "", for: record.problemID)
                    }

                HStack {
                    Text("ID \(record.problemID)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        showMarkdownFor = record
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.plain)
                    .font(.title3)
                    Button {
                        toggleUnstar()
                    } label: {
                        Image(systemName: isPendingUnstar ? "star" : "star.fill")
                    }
                    .buttonStyle(.plain)
                    .font(.title3)
                    .foregroundStyle(isPendingUnstar ? Color.secondary : Color.yellow)
                }
            }
            .padding(.vertical, 4)
            .opacity(isPendingUnstar ? 0.5 : 1)
            .swipeActions {
                Button("Remove", role: .destructive) {
                    model.removeKey(record.problemID)
                    pendingUnstar.remove(record.problemID)
                }
            }
        }
    }

    private var isPendingUnstar: Bool { pendingUnstar.contains(record.problemID) }

    private func toggleUnstar() {
        if isPendingUnstar {
            pendingUnstar.remove(record.problemID)
        } else {
            pendingUnstar.insert(record.problemID)
        }
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { noteDrafts[record.problemID] ?? model.keyNote(for: record.problemID) ?? "" },
            set: { noteDrafts[record.problemID] = $0 }
        )
    }
}

/// `fileExporter` needs a document to name the destination; the real bytes are written by
/// the exporter once KaTeX has signalled the page is fully typeset — mirrors `SessionsView`'s
/// `SessionPDFDocument`.
private struct KeyPDFDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}
