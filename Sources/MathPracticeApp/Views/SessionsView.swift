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
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startedAt, style: .date) + Text(" · ") + Text(session.startedAt, style: .time)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.key.map { model.registry.displayName(for: $0) } ?? "—")
                    Spacer()
                    outcomeLabel(for: entry)
                }
                HStack(spacing: 8) {
                    if let difficulty = entry.difficulty {
                        Text("Level \(difficulty)")
                    }
                    if let problemID = entry.problemID {
                        Text("ID \(problemID)").monospaced().textSelection(.enabled)
                    }
                    Spacer()
                    Text(entry.createdAt, style: .time)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if let note = entry.skipNote {
                    Text("“\(note)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                if let problemID = entry.problemID {
                    HStack {
                        Button {
                            toggleKey(for: entry, problemID: problemID)
                        } label: {
                            Label(
                                model.isKey(problemID) ? "Key" : "Mark as key",
                                systemImage: model.isKey(problemID) ? "star.fill" : "star"
                            )
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(model.isKey(problemID) ? .yellow : .secondary)
                        .disabled(!model.isKey(problemID) && model.regenerate(entry) == nil)
                        Spacer()
                    }
                    if model.isKey(problemID) {
                        TextField("Note about this problem", text: noteBinding(for: problemID))
                            .font(.caption2)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                model.setKeyNote(noteDrafts[problemID] ?? "", for: problemID)
                            }
                    }
                }
            }
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

    private func toggleKey(for entry: SessionEntry, problemID: String) {
        if model.isKey(problemID) {
            model.removeKey(problemID)
        } else if let problem = model.regenerate(entry) {
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
                Label("Right", systemImage: "checkmark.circle").foregroundStyle(.green)
            case .incorrect:
                Label("Wrong", systemImage: "xmark.circle").foregroundStyle(.red)
            case nil:
                Label("Skipped", systemImage: "arrow.uturn.forward").foregroundStyle(.secondary)
            }
        }
        .font(.caption)
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
