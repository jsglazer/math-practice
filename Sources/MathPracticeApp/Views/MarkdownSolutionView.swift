//  MarkdownSolutionView.swift
//  A pop-up showing the current problem (and whatever has been revealed of it) typeset —
//  not as raw Markdown source — so it reads the way it would once pasted into Obsidian.
//  The Copy button still puts the plain-Markdown source (math wrapped in single dollar
//  signs) on the clipboard, ready to paste into any Markdown-aware app.

import SwiftUI

struct MarkdownSolutionView: View {
    let markdown: String
    let blocks: [MathBlock]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                MathTextView(blocks: blocks, minHeight: 60)
                    .padding(12)
            }
            .textSelection(.enabled)
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
