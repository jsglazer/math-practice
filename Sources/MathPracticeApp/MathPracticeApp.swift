//  MathPracticeApp.swift
//  Entry point. Builds the two-store container, mints the device identity, and hands both
//  to the single `AppModel`.

import MathPracticeCore
import SwiftData
import SwiftUI

@main
struct MathPracticeApp: App {
    @State private var launch = LaunchState()

    var body: some Scene {
        WindowGroup {
            switch launch.outcome {
            case let .ready(model, container):
                RootView()
                    .environment(model)
                    .modelContainer(container)
                    .task { model.start() }
            case let .failed(message):
                LaunchFailureView(message: message)
            }
        }
        #if os(macOS)
        .defaultSize(width: 980, height: 720)
        #endif
    }
}

/// Container creation can fail (a corrupt store, a missing iCloud entitlement). Failing
/// into a readable screen beats a crash on launch with nothing to go on.
@MainActor
@Observable
private final class LaunchState {
    enum Outcome {
        case ready(AppModel, ModelContainer)
        case failed(String)
    }

    let outcome: Outcome

    init() {
        do {
            let container = try Persistence.makeContainer()
            let model = AppModel(
                context: container.mainContext,
                deviceID: DeviceID(DeviceIdentity.current())
            )
            outcome = .ready(model, container)
        } catch {
            outcome = .failed(error.localizedDescription)
        }
    }
}

private struct LaunchFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Could not open the practice database", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        }
        .padding()
    }
}
