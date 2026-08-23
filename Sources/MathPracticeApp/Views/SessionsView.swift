//  SessionsView.swift
//  Every past practice session, folded out of the event stream — nothing here is stored
//  beyond the events themselves. Tap a session to review exactly what was worked, skipped,
//  and self-reported, each problem carrying the ID that was shown while practising it.

import MathPracticeCore
import SwiftUI
import UniformTypeIdentifiers

struct SessionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                if model.sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Work or skip a problem and it shows up here.")
                    )
                } else {
                    ForEach(model.sessions) { session in
                        NavigationLink(value: session.id) {
                            SessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: UUID.self) { id in
                if let session = model.sessions.first(where: { $0.id == id }) {
                    SessionDetailView(session: session)
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: PracticeSession

    var body: some View {
        HStack(spacing: 12) {
            Text(session.startedAt, style: .date) + Text(" · ") + Text(session.startedAt, style: .time)
            Spacer()
            HStack(spacing: 12) {
                Label("\(session.correct)/\(session.attempts) right", systemImage: "checkmark.circle")
                if session.skips > 0 {
                    Label("\(session.skips) skipped", systemImage: "arrow.uturn.forward")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct SessionDetailView: View {
    @Environment(AppModel.self) private var model
    let session: PracticeSession

    @State private var pendingExportDetail: SessionExportDetail?
    @State private var noteDrafts: [String: String] = [:]

    var body: some View {
        List(session.entries) { entry in
            SessionEntryRow(entry: entry, noteDrafts: $noteDrafts)
        }
        .navigationTitle(Text(session.startedAt, style: .date))
        .toolbar {
            if model.sessionExporter != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Export PDF", systemImage: "square.and.arrow.up") {
                        ForEach(SessionExportDetail.allCases) { detail in
                            Button(detail.displayName) { pendingExportDetail = detail }
                        }
                    }
                }
            }
        }
        .fileExporter(
            isPresented: Binding(
                get: { pendingExportDetail != nil },
                set: { if !$0 { pendingExportDetail = nil } }
            ),
            document: SessionPDFDocument(),
            contentType: .pdf,
            defaultFilename: model.sessionExporter?.suggestedFilename(for: session) ?? "Session.pdf"
        ) { result in
            guard case let .success(url) = result, let detail = pendingExportDetail else {
                pendingExportDetail = nil
                return
            }
            pendingExportDetail = nil
            Task { await model.exportSession(session, detail: detail, to: url) }
        }
    }
}

/// One session entry, laid out as a single line: topic · sub-topic, level, ID, the Key
/// star, whether it was got right, the equation itself, and the time — plus a button that
/// pops up the equation (only — no metadata) as copyable, typeset Markdown. The skip note
/// and the Key note editor, being variable-height and only sometimes present, still render
/// as an optional second line beneath the single-line row rather than crowding it.
private struct SessionEntryRow: View {
    @Environment(AppModel.self) private var model
    let entry: SessionEntry
    @Binding var noteDrafts: [String: String]

    @State private var showMarkdownSheet = false

    private var problem: GeneratedProblem? { model.regenerate(entry) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(entry.key.map { model.registry.displayName(for: $0) } ?? "—")
                    .font(.caption)
                    .lineLimit(1)

                if let difficulty = entry.difficulty {
                    Text("L\(difficulty)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let problemID = entry.problemID {
                    Text(problemID)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button {
                        toggleKey(problemID: problemID)
                    } label: {
                        Image(systemName: model.isKey(problemID) ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                    .font(.title3)
                    .foregroundStyle(model.isKey(problemID) ? .yellow : .secondary)
                    .disabled(!model.isKey(problemID) && problem == nil)
                }

                outcomeLabel(for: entry)

                if let problem {
                    MathTextView(latex: problem.promptLatex, minHeight: 24)
                        .frame(maxWidth: 180)
                } else if entry.problemID != nil {
                    Text("Question text unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                Spacer(minLength: 4)

                Text(entry.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if problem != nil {
                    Button {
                        showMarkdownSheet = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            if let note = entry.skipNote {
                Text("“\(note)”")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            if let problemID = entry.problemID, let problem {
                TextField("Note", text: noteBinding(for: problemID))
                    .font(.caption2)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.setNote(noteDrafts[problemID] ?? "", for: problem)
                    }
            }
        }
        .sheet(isPresented: $showMarkdownSheet) {
            if let problem {
                MarkdownSolutionView(markdown: "$\(problem.promptLatex)$")
            }
        }
    }

    private func toggleKey(problemID: String) {
        if model.isKey(problemID) {
            model.removeKey(problemID)
        } else if let problem {
            model.toggleKey(for: problem)
            noteDrafts[problemID] = ""
        }
    }

    private func noteBinding(for problemID: String) -> Binding<String> {
        Binding(
            get: { noteDrafts[problemID] ?? model.keyNote(for: problemID) ?? "" },
            set: { noteDrafts[problemID] = $0 }
        )
    }

    private func outcomeLabel(for entry: SessionEntry) -> some View {
        Group {
            switch entry.outcome {
            case .correct:
                Label("Yes", systemImage: "checkmark.circle").foregroundStyle(.green)
            case .incorrect:
                Label("No", systemImage: "xmark.circle").foregroundStyle(.red)
            case nil:
                Label("Skip", systemImage: "arrow.uturn.forward").foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .labelStyle(.titleAndIcon)
    }
}

/// `fileExporter` needs a document to name the destination; the real bytes are written by
/// the exporter once KaTeX has signalled that the page is fully typeset — see `WorksheetsView`'s
/// `PlaceholderPDFDocument`, which this mirrors for sessions.
private struct SessionPDFDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}
