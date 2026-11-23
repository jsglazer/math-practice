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
        // The ActivityWatch heartbeat reports which tab is on screen.
        .onChange(of: selectedTab, initial: true) { _, tab in
            model.activeTab = tab.activityTab
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

    var activityTab: ActivityTab {
        switch self {
        case .practice: return .practice
        case .progress: return .progress
        case .sessions: return .sessions
        case .key: return .key
        case .worksheets: return .worksheets
        case .settings: return .settings
        }
    }
}

/// The topic / sub-type / difficulty selector, shared by practice and worksheet creation.
/// `accessory` rides at the trailing end of the custom-mix row (or the "Custom mix…" row) —
/// Practice puts the problem ID and note there so the whole thing reads as one line.
struct SelectionControls<Accessory: View>: View {
    @Environment(AppModel.self) private var model
    @State private var showCustomMixSheet = false
    private let accessory: Accessory

    init(@ViewBuilder accessory: () -> Accessory) {
        self.accessory = accessory()
    }

    var body: some View {
        @Bindable var model = model
        Group {
            if model.customMixEnabled {
                HStack(spacing: 10) {
                    Text("Custom mix")
                    Button("Edit…") { showCustomMixSheet = true }
                    Button("Clear", role: .destructive) { model.clearCustomMix() }
                    Text("\(model.customMixSelectedKeys.count) sub-type\(model.customMixSelectedKeys.count == 1 ? "" : "s") · Level \(model.customMixDifficulty)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    Spacer(minLength: 12)
                    accessory
                }
            } else {
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

                HStack(spacing: 10) {
                    Button("Custom mix…") { showCustomMixSheet = true }
                    Spacer(minLength: 12)
                    accessory
                }
            }
        }
        .sheet(isPresented: $showCustomMixSheet) {
            CustomMixSheet()
        }
    }
}

extension SelectionControls where Accessory == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
