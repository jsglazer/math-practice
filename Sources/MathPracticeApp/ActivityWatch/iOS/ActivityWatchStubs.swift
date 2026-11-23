//  ActivityWatchStubs.swift
//  The iOS twins of `ActivityWatch/macOS/`. ActivityWatch has no iOS server, so iOS sends
//  nothing and shows no settings for it; these exist only so shared code needs no
//  `#if os(...)` (the macOS target excludes this folder).

import MathPracticeCore
import SwiftUI

@MainActor
final class ActivityWatchService {
    func start(
        context: @escaping @MainActor () -> ActivityContext?,
        isEnabled: @escaping @MainActor () -> Bool,
        server: @escaping @MainActor () -> String
    ) {}
}

struct ActivityWatchSettingsSection: View {
    var body: some View {
        EmptyView()
    }
}
