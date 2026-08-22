//  SessionsView.swift
//  Every past practice session, folded out of the event stream — nothing here is stored
//  beyond the events themselves. Tap a session to review exactly what was worked, skipped,
//  and self-reported, each problem carrying the ID that was shown while practising it.

import MathPracticeCore
import SwiftUI

struct SessionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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
                        Text("ID \(problemID)").monospaced()
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
            }
        }
        .navigationTitle(Text(session.startedAt, style: .date))
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
