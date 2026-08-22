//  RootView.swift
//  Six places to be: practice, progress, sessions, key problems, worksheets, settings.

import MathPracticeCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedTab: RootTab = .practice

    var body: some View {
        ZStack {
            // Hidden, zero-size buttons: the only way to attach `.keyboardShortcut` so it's
            // live everywhere in this view regardless of which tab (and its own toolbar
            // shortcuts) currently has focus.
            Button("", action: { moveTab(by: -1) })
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .opacity(0)
            Button("", action: { moveTab(by: 1) })
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .opacity(0)

            TabView(selection: $selectedTab) {
                PracticeView()
                    .tabItem { Label("Practice", systemImage: "function") }
                    .tag(RootTab.practice)
                DashboardView()
                    .tabItem { Label("Progress", systemImage: "chart.bar") }
                    .tag(RootTab.progress)
                SessionsView()
                    .tabItem { Label("Sessions", systemImage: "list.bullet.clipboard") }
                    .tag(RootTab.sessions)
                KeyView()
                    .tabItem { Label("Key", systemImage: "star") }
                    .tag(RootTab.key)
                WorksheetsView()
                    .tabItem { Label("Worksheets", systemImage: "doc.text") }
                    .tag(RootTab.worksheets)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(RootTab.settings)
            }
        }
    }

    private func moveTab(by delta: Int) {
        let all = RootTab.allCases
        guard let currentIndex = all.firstIndex(of: selectedTab) else { return }
        let newIndex = (currentIndex + delta + all.count) % all.count
        selectedTab = all[newIndex]
    }
}

/// `Cmd-Shift-[` / `Cmd-Shift-]` (documented in Settings) cycle through these in order.
private enum RootTab: CaseIterable {
    case practice, progress, sessions, key, worksheets, settings
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
