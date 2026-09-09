//  CustomMixSheet.swift
//  Nested checkboxes — topics, expanded to their sub-types — for building a custom pool of
//  what to draw from at one fixed difficulty. "Start" hands the pool to AppModel, which then
//  draws a fresh random member of it for every problem (see `nextPracticeRequest()`).

import MathPracticeCore
import SwiftUI

struct CustomMixSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKeys: Set<PracticeKey> = []
    @State private var difficulty = 3

    var body: some View {
        NavigationStack {
            Form {
                ForEach(model.registry.topics, id: \.id) { topic in
                    Section {
                        ForEach(topic.subTypes) { subType in
                            Toggle(subType.displayName, isOn: binding(for: PracticeKey(topic: topic.id, subType: subType.id)))
                        }
                    } header: {
                        HStack {
                            Text(topic.displayName)
                            Spacer()
                            Button(allChecked(in: topic) ? "Deselect all" : "Select all") {
                                toggleAll(in: topic)
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                        }
                    }
                }

                Section("Difficulty") {
                    Picker("Level", selection: $difficulty) {
                        ForEach(Array(DifficultyLadder.bounds), id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                }

                if selectedKeys.isEmpty {
                    Section {
                        Text("Check at least one sub-type to start.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Custom mix")
            .onAppear {
                selectedKeys = model.customMixSelectedKeys
                difficulty = model.customMixDifficulty
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        model.applyCustomMix(keys: selectedKeys, difficulty: difficulty)
                        dismiss()
                    }
                    .disabled(selectedKeys.isEmpty)
                }
            }
        }
    }

    private func binding(for key: PracticeKey) -> Binding<Bool> {
        Binding(
            get: { selectedKeys.contains(key) },
            set: { isOn in
                if isOn {
                    selectedKeys.insert(key)
                } else {
                    selectedKeys.remove(key)
                }
            }
        )
    }

    private func allChecked(in topic: any TopicModule) -> Bool {
        topic.subTypes.allSatisfy { selectedKeys.contains(PracticeKey(topic: topic.id, subType: $0.id)) }
    }

    private func toggleAll(in topic: any TopicModule) {
        let keys = topic.subTypes.map { PracticeKey(topic: topic.id, subType: $0.id) }
        if allChecked(in: topic) {
            keys.forEach { selectedKeys.remove($0) }
        } else {
            keys.forEach { selectedKeys.insert($0) }
        }
    }
}
