//  RootView.swift
//  Four places to be: practice, progress, worksheets, settings.

import MathPracticeCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            PracticeView()
                .tabItem { Label("Practice", systemImage: "function") }
            DashboardView()
                .tabItem { Label("Progress", systemImage: "chart.bar") }
            SessionsView()
                .tabItem { Label("Sessions", systemImage: "list.bullet.clipboard") }
            WorksheetsView()
                .tabItem { Label("Worksheets", systemImage: "doc.text") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

/// The topic / sub-type / difficulty selector, shared by practice and worksheet creation.
struct SelectionControls: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            Picker("Topic", selection: $model.selectedTopic) {
                Text("Random mix").tag(TopicID?.none)
                ForEach(model.registry.topics, id: \.id) { topic in
                    Text(topic.displayName).tag(TopicID?.some(topic.id))
                }
            }

            Picker("Sub-type", selection: $model.selectedSubType) {
                Text("Random mix").tag(SubTypeID?.none)
                ForEach(model.subTypesForSelectedTopic) { subType in
                    Text(subType.displayName).tag(SubTypeID?.some(subType.id))
                }
            }
            .disabled(model.selectedTopic == nil)

            Toggle("Adaptive difficulty", isOn: $model.useAdaptiveDifficulty)

            if model.useAdaptiveDifficulty {
                LabeledContent("Level", value: "\(model.effectiveDifficulty)")
            } else {
                Picker("Level", selection: $model.chosenDifficulty) {
                    ForEach(Array(DifficultyLadder.bounds), id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
            }
        }
    }
}
