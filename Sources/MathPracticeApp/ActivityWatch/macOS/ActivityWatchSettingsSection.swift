//  ActivityWatchSettingsSection.swift
//  Settings → ActivityWatch: the on/off switch, the server URL and the last heartbeat's status.

import MathPracticeCore
import SwiftUI

/// The ActivityWatch switch, server URL and last-heartbeat status.
struct ActivityWatchSettingsSection: View {
    @Environment(AppModel.self) private var model
    @State private var serverDraft = ""

    var body: some View {
        Section {
            Toggle("Send activity to ActivityWatch", isOn: Binding(
                get: { model.activityWatchEnabled },
                set: { model.setActivityWatchEnabled($0) }
            ))
            HStack {
                TextField("Server URL", text: $serverDraft, prompt: Text(ActivityWatchAPI.defaultServer))
                    .onSubmit { model.setActivityWatchServer(serverDraft) }
                Button("Save") { model.setActivityWatchServer(serverDraft) }
                    .disabled(serverDraft == model.activityWatchServer)
            }
            LabeledContent("Bucket", value: model.activityWatch.bucket ?? "—")
            LabeledContent("Last heartbeat", value: statusText)
        } header: {
            Text("ActivityWatch")
        } footer: {
            Text("While MathPractice is the active app, it reports the class, tab, topic, sub-type, level, problem ID and mode every 30 s and whenever they change. Nothing is sent when ActivityWatch isn't running.")
        }
        .onAppear { serverDraft = model.activityWatchServer }
    }

    private var statusText: String {
        guard model.activityWatchEnabled else { return "Off" }
        guard let time = model.activityWatch.lastHeartbeat, let result = model.activityWatch.lastResult else {
            return "None yet"
        }
        let stamp = time.formatted(date: .omitted, time: .standard)
        switch result {
        case .sent: return "\(stamp) · sent"
        case .notRunning: return "\(stamp) · ActivityWatch not running"
        }
    }
}
