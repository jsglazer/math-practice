//  WorksheetsView.swift
//  Name a worksheet, export it, work it on paper, come back and click Right/Wrong by number.
//
//  The export button is present only when the platform supplies a `WorksheetExporting`
//  conformance — on iOS `model.worksheetExporter` is `nil` and the affordance is simply
//  absent. There is no `#if os(macOS)` in this file.

import MathPracticeCore
import SwiftUI
import UniformTypeIdentifiers

struct WorksheetsView: View {
    @Environment(AppModel.self) private var model

    @State private var newName = ""
    @State private var questionCount = 10
    @State private var pendingExport: Worksheet?

    var body: some View {
        NavigationStack {
            Form {
                Section("New worksheet") {
                    TextField("Name", text: $newName, prompt: Text("Derivs 0821"))
                    Stepper("\(questionCount) questions", value: $questionCount, in: 1...50)
                    SelectionControls()
                    Button("Create") {
                        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        // Persist first: the PDF renders from the saved record, so the
                        // printed numbers and the self-report rows cannot diverge.
                        if let worksheet = model.createWorksheet(name: name, questionCount: questionCount) {
                            newName = ""
                            if model.worksheetExporter != nil {
                                pendingExport = worksheet
                            }
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Saved worksheets") {
                    if model.worksheets.isEmpty {
                        Text("No worksheets yet.").foregroundStyle(.secondary)
                    }
                    ForEach(model.worksheets) { worksheet in
                        NavigationLink {
                            WorksheetReportView(worksheet: worksheet)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(worksheet.name)
                                Text(subtitle(for: worksheet))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if model.worksheetExporter != nil {
                                Button("Export PDF") { pendingExport = worksheet }
                            }
                        }
                    }
                }

                if let error = model.lastError {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Worksheets")
            .fileExporter(
                isPresented: Binding(
                    get: { pendingExport != nil },
                    set: { if !$0 { pendingExport = nil } }
                ),
                document: PlaceholderPDFDocument(),
                contentType: .pdf,
                defaultFilename: pendingExport.flatMap { worksheet in
                    model.worksheetExporter?.suggestedFilename(for: worksheet)
                } ?? "Worksheet.pdf"
            ) { result in
                guard case let .success(url) = result, let worksheet = pendingExport else {
                    pendingExport = nil
                    return
                }
                pendingExport = nil
                Task { await model.exportWorksheet(worksheet, to: url) }
            }
        }
    }
}

private extension WorksheetsView {
    func subtitle(for worksheet: Worksheet) -> String {
        let stamp = worksheet.createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(worksheet.questions.count) questions · \(stamp)"
    }
}

/// `fileExporter` needs a document to name the destination; the real bytes are written by
/// the exporter once KaTeX has signalled that the page is fully typeset.
private struct PlaceholderPDFDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}

/// Click Right/Wrong for each printed question, by its number.
struct WorksheetReportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let worksheet: Worksheet
    @State private var outcomes: [Int: AttemptOutcome] = [:]

    var body: some View {
        Form {
            Section {
                ForEach(worksheet.questions) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(question.number).")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: binding(for: question.number)) {
                                Text("—").tag(AttemptOutcome?.none)
                                Text("Right").tag(AttemptOutcome?.some(.correct))
                                Text("Wrong").tag(AttemptOutcome?.some(.incorrect))
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 200)
                        }
                        MathTextView(latex: question.problem.promptLatex, minHeight: 56)
                    }
                }
            } header: {
                Text("Question numbers match the printed sheet")
            }

            Section {
                Button("Record \(outcomes.count) result\(outcomes.count == 1 ? "" : "s")") {
                    model.recordWorksheetResults(worksheet, outcomes: outcomes)
                    dismiss()
                }
                .disabled(outcomes.isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(worksheet.name)
    }

    private func binding(for number: Int) -> Binding<AttemptOutcome?> {
        Binding(
            get: { outcomes[number] },
            set: { outcomes[number] = $0 }
        )
    }
}
