//  ClassAndNoteControls.swift
//  Small controls shared across tabs: the class picker, and the Markdown note field with
//  its pop-up editor.

import SwiftUI

/// Picks a class tag: `nil` (the fallback, labelled by `nilLabel`), a listed class, or `""`
/// for "No class". A tag that is no longer in the list is still offered, so opening a picker
/// never silently re-tags anything.
struct ClassPicker: View {
    @Environment(AppModel.self) private var model

    let title: String
    let nilLabel: String
    @Binding var selection: String?

    var body: some View {
        Picker(title, selection: $selection) {
            Text(nilLabel).tag(String?.none)
            ForEach(options, id: \.self) { name in
                Text(name).tag(String?.some(name))
            }
            Text("No class").tag(String?.some(""))
        }
    }

    private var options: [String] {
        var names = model.classNames
        if let selection, !selection.isEmpty, !names.contains(selection) {
            names.append(selection)
        }
        return names
    }
}

/// Renders a note's Markdown (bold, italics, code, links), keeping its line breaks.
struct MarkdownNoteText: View {
    let note: String

    var body: some View {
        Text(Self.attributed(note))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func attributed(_ note: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: note, options: options)) ?? AttributedString(note)
    }
}

/// A one-line note field with a button that pops up a larger Markdown editor. `onCommit`
/// saves; it runs on Return in the field and on Save in the pop-up.
struct NoteField: View {
    @Binding var text: String
    var onCommit: () -> Void

    @State private var showEditor = false

    var body: some View {
        HStack(spacing: 4) {
            TextField("Note", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onCommit)
            Button {
                showEditor = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .help("Open a larger note editor")
        }
        .sheet(isPresented: $showEditor) {
            NoteEditorSheet(initial: text) { edited in
                text = edited
                onCommit()
            }
        }
    }
}

/// The larger note editor: Markdown source on top, a live rendered preview below.
struct NoteEditorSheet: View {
    let initial: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                TextEditor(text: $draft)
                    .font(.body.monospaced())
                    .frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4)))
                Text("Preview").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    MarkdownNoteText(note: draft.isEmpty ? "*Nothing yet*" : draft)
                }
                .frame(minHeight: 80)
                Text(verbatim: "Markdown: **bold**, *italic*, `code`, [link](url)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
            .onAppear { draft = initial }
        }
        // A suggestion, not a floor: macOS sizes the sheet to it, iOS sheets fill anyway.
        .frame(idealWidth: 560, idealHeight: 460)
    }
}
