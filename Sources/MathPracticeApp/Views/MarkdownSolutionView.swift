//  MarkdownSolutionView.swift
//  A pop-up showing the current problem (and whatever has been revealed of it) as plain
//  Markdown, math wrapped in single dollar signs, so it can be selected — or copied with one
//  tap — and pasted straight into Obsidian or any other Markdown-aware app.

import SwiftUI

struct MarkdownSolutionView: View {
    let markdown: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: .constant(markdown))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(4)
                .navigationTitle("Markdown")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Copy", systemImage: "doc.on.doc") { PlatformClipboard.copy(markdown) }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
