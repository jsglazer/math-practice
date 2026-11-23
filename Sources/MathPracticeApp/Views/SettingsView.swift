//  SettingsView.swift
//  Ladder thresholds and manual level overrides.
//
//  Both are recorded as events in the synced stream, never in UserDefaults: a threshold in
//  local defaults would let two devices derive different levels from the same history.

import MathPracticeCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var stepUp = LadderConfiguration.default.stepUpThreshold
    @State private var stepDown = LadderConfiguration.default.stepDownThreshold
    @State private var hold = LadderConfiguration.default.holdPeriod
    @State private var pinKey: PracticeKey?
    @State private var pinLevel = 1

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        "Harder after \(stepUp) correct in a row",
                        value: $stepUp,
                        in: LadderConfiguration.stepUpBounds
                    )
                    Stepper(
                        "Easier after \(stepDown) wrong in a row",
                        value: $stepDown,
                        in: LadderConfiguration.stepDownBounds
                    )
                    Stepper(
                        "Hold \(hold) attempts before stepping down again",
                        value: $hold,
                        in: LadderConfiguration.holdBounds
                    )
                    Button("Save thresholds") {
                        model.updateConfiguration(
                            LadderConfiguration(stepUpThreshold: stepUp, stepDownThreshold: stepDown, holdPeriod: hold)
                        )
                    }
                    .disabled(!hasChanges)
                } header: {
                    Text("Difficulty ladder")
                } footer: {
                    Text("Saved as an event in the synced log, so every device resolves the same thresholds.")
                }

                Section("Set a level by hand") {
                    Picker("Sub-type", selection: $pinKey) {
                        Text("Choose…").tag(PracticeKey?.none)
                        ForEach(model.practiceKeys, id: \.self) { key in
                            Text(model.registry.displayName(for: key)).tag(PracticeKey?.some(key))
                        }
                    }
                    Picker("Level", selection: $pinLevel) {
                        ForEach(Array(DifficultyLadder.bounds), id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                    Button("Pin level") {
                        if let pinKey {
                            model.pinLevel(pinLevel, for: pinKey)
                        }
                    }
                    .disabled(pinKey == nil)
                }

                ClassesSettingsSection()

                // Empty on iOS: ActivityWatch has no iOS server.
                ActivityWatchSettingsSection()

                Section("Problem packs") {
                    PackImportControl()
                }

                Section("Keyboard shortcuts") {
                    LabeledContent("Previous tab", value: "⌘⇧[")
                    LabeledContent("Next tab", value: "⌘⇧]")
                }

                Section("Sync health") {
                    LabeledContent("Events in log", value: "\(model.events.count)")
                    LabeledContent("Duplicates removed", value: "\(duplicatesRemoved)")
                    Button("Run deduplication now") {
                        model.deduplication.runPass()
                        model.reload()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .onAppear(perform: loadCurrentConfiguration)
        }
    }

    private var duplicatesRemoved: Int {
        model.deduplication.lastPassRemoved.values.reduce(0, +)
    }

    private var hasChanges: Bool {
        LadderConfiguration(stepUpThreshold: stepUp, stepDownThreshold: stepDown, holdPeriod: hold)
            != model.configuration
    }

    private func loadCurrentConfiguration() {
        let current = model.configuration
        stepUp = current.stepUpThreshold
        stepDown = current.stepDownThreshold
        hold = current.holdPeriod
    }
}

/// The file-import affordance for LLM-authored packs.
private struct PackImportControl: View {
    @Environment(AppModel.self) private var model
    @State private var isPresented = false
    @State private var message: String?

    var body: some View {
        Button("Import a pack…") { isPresented = true }
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.json]) { result in
                switch result {
                case let .success(url):
                    message = model.importPack(at: url)
                case let .failure(error):
                    message = error.localizedDescription
                }
            }
        if let message {
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The class list every class picker offers, and this device's Default class.
private struct ClassesSettingsSection: View {
    @Environment(AppModel.self) private var model
    @State private var newClass = ""

    var body: some View {
        Section {
            Picker("Default class", selection: Binding(
                get: { model.defaultClassName },
                set: { model.setDefaultClassName($0) }
            )) {
                ForEach(defaultOptions, id: \.self) { name in
                    Text(name).tag(name)
                }
                Text("No class").tag("")
            }
            ForEach(model.classNames, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Button(role: .destructive) {
                        if let index = model.classNames.firstIndex(of: name) {
                            model.removeClassNames(at: IndexSet(integer: index))
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove from the class list")
                }
            }
            HStack {
                TextField("Add a class", text: $newClass, prompt: Text("Econ - PUBP 720"))
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(newClass.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Classes")
        } footer: {
            Text("Spell each class exactly as the Classes dashboard names it (its folder under ~/VaultSchar/Classes/<term>/). The Default class is what untagged practice counts toward on this device.")
        }
    }

    /// The listed classes, plus the current default if it was removed from the list.
    private var defaultOptions: [String] {
        var names = model.classNames
        if !model.defaultClassName.isEmpty, !names.contains(model.defaultClassName) {
            names.append(model.defaultClassName)
        }
        return names
    }

    private func add() {
        model.addClassName(newClass)
        newClass = ""
    }
}
